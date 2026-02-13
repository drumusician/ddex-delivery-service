defmodule DdexDeliveryServiceWeb.DemoLive do
  use DdexDeliveryServiceWeb, :live_view

  alias DdexDeliveryService.Ingestion.Ingest

  defp system_actor, do: %DdexDeliveryService.Accounts.SystemActor{}

  @impl true
  def mount(_params, _session, socket) do
    # Create or find a demo org for the demo UI
    org = get_or_create_demo_org()

    {:ok,
     socket
     |> assign(
       page_title: "Demo",
       delivery: nil,
       release: nil,
       tracks: [],
       status_steps: [],
       current_tab: "parsed",
       error: nil,
       processing: false,
       org_id: org.id,
       upload_mode: :single
     )
     |> allow_upload(:xml_file, accept: ~w(.xml), max_entries: 1, max_file_size: 10_000_000)
     |> allow_upload(:package_files,
       accept:
         ~w(.xml .flac .wav .mp3 .aac .jpg .jpeg .png .pdf),
       max_entries: 20,
       max_file_size: 500_000_000
     )}
  end

  defp get_or_create_demo_org do
    case DdexDeliveryService.Accounts.get_organization_by_slug("demo", actor: system_actor()) do
      {:ok, org} ->
        org

      _ ->
        {:ok, org} =
          DdexDeliveryService.Accounts.create_organization(
            %{name: "Demo Organization", slug: "demo"},
            actor: system_actor()
          )

        org
    end
  end

  @impl true
  def handle_event("use_sample", %{"version" => version}, socket) do
    {:ok, delivery} = Ingest.ingest_sample(socket.assigns.org_id, version)

    Phoenix.PubSub.subscribe(DdexDeliveryService.PubSub, "delivery:#{delivery.id}")

    {:noreply,
     socket
     |> assign(
       delivery: delivery,
       processing: true,
       status_steps: [%{label: "Received", status: :done, detail: nil}],
       error: nil,
       release: nil,
       tracks: []
     )}
  rescue
    e ->
      {:noreply, assign(socket, error: "Failed to ingest sample: #{Exception.message(e)}")}
  end

  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("switch_upload_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, upload_mode: String.to_existing_atom(mode))}
  end

  def handle_event("upload_xml", _params, socket) do
    [xml_content] =
      consume_uploaded_entries(socket, :xml_file, fn %{path: path}, entry ->
        content = File.read!(path)
        {:ok, {content, entry.client_name}}
      end)

    {xml, filename} = xml_content
    {:ok, delivery} = Ingest.ingest_xml(xml, socket.assigns.org_id, filename)

    Phoenix.PubSub.subscribe(DdexDeliveryService.PubSub, "delivery:#{delivery.id}")

    {:noreply,
     socket
     |> assign(
       delivery: delivery,
       processing: true,
       status_steps: [%{label: "Received", status: :done, detail: nil}],
       error: nil,
       release: nil,
       tracks: []
     )}
  rescue
    e ->
      {:noreply, assign(socket, error: "Failed to start processing: #{Exception.message(e)}")}
  end

  def handle_event("upload_package", _params, socket) do
    # Consume all uploaded files, separating XML from resources
    uploaded_files =
      consume_uploaded_entries(socket, :package_files, fn %{path: path}, entry ->
        # Copy to a temp file that persists after consume
        tmp_path = System.tmp_dir!() |> Path.join("ddex_upload_#{Ash.UUID.generate()}_#{entry.client_name}")
        File.cp!(path, tmp_path)
        {:ok, %{path: tmp_path, filename: entry.client_name, content_type: entry.client_type}}
      end)

    # Separate XML from resources
    {xml_files, resource_files} =
      Enum.split_with(uploaded_files, fn file ->
        String.ends_with?(file.filename, ".xml")
      end)

    case xml_files do
      [xml_file | _] ->
        xml_content = File.read!(xml_file.path)

        {:ok, delivery} =
          Ingest.ingest_package(
            xml_content,
            resource_files,
            socket.assigns.org_id,
            xml_file.filename
          )

        # Clean up temp files
        for file <- uploaded_files, do: File.rm(file.path)

        Phoenix.PubSub.subscribe(DdexDeliveryService.PubSub, "delivery:#{delivery.id}")

        {:noreply,
         socket
         |> assign(
           delivery: delivery,
           processing: true,
           status_steps: [%{label: "Received", status: :done, detail: nil}],
           error: nil,
           release: nil,
           tracks: []
         )}

      [] ->
        for file <- uploaded_files, do: File.rm(file.path)
        {:noreply, assign(socket, error: "No XML metadata file found in uploaded files")}
    end
  rescue
    e ->
      {:noreply, assign(socket, error: "Failed to process package: #{Exception.message(e)}")}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, current_tab: tab)}
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(
       delivery: nil,
       release: nil,
       tracks: [],
       status_steps: [],
       current_tab: "parsed",
       error: nil,
       processing: false,
       upload_mode: :single
     )}
  end

  @impl true
  def handle_info({:delivery_status, %{status: :processing}}, socket) do
    {:noreply, add_step(socket, "Processing", :done)}
  end

  def handle_info({:delivery_status, %{status: :detecting_version, version: v}}, socket) do
    {:noreply, add_step(socket, "ERN version detected: #{v}", :done)}
  end

  def handle_info({:delivery_status, %{status: :validating}}, socket) do
    {:noreply, add_step(socket, "Validating identifiers", :done)}
  end

  def handle_info({:delivery_status, %{status: :parsing}}, socket) do
    {:noreply, add_step(socket, "Parsing release metadata", :done)}
  end

  def handle_info({:delivery_status, %{status: :persisting}}, socket) do
    {:noreply, add_step(socket, "Persisting to database", :done)}
  end

  def handle_info({:delivery_status, %{status: :completed, release_id: release_id}}, socket) do
    actor = system_actor()
    tenant = socket.assigns.org_id

    release =
      DdexDeliveryService.Catalog.get_release_by_id!(release_id,
        load: [:artists, :label, :deals, tracks: [:artists]],
        actor: actor,
        tenant: tenant
      )

    tracks =
      release.tracks
      |> Enum.sort_by(& &1.track_number)

    # Reload delivery to get updated ern_version
    delivery =
      DdexDeliveryService.Ingestion.get_delivery_by_id!(socket.assigns.delivery.id,
        actor: actor,
        tenant: tenant
      )

    {:noreply,
     socket
     |> add_step("Complete!", :done)
     |> assign(
       processing: false,
       delivery: delivery,
       release: release,
       tracks: tracks
     )}
  end

  def handle_info({:delivery_status, %{status: :failed, error: error}}, socket) do
    {:noreply,
     socket
     |> add_step("Failed: #{error}", :error)
     |> assign(processing: false, error: error)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp add_step(socket, label, status, detail \\ nil) do
    steps = socket.assigns.status_steps ++ [%{label: label, status: status, detail: detail}]
    assign(socket, status_steps: steps)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <div class="mx-auto max-w-6xl px-6 py-8 sm:py-12">
        <%!-- Header --%>
        <div class="mb-8 sm:mb-10">
          <.link navigate={~p"/"} class="text-sm text-base-content/50 hover:text-primary flex items-center gap-1 mb-4">
            <.icon name="hero-arrow-left" class="size-4" />
            Back to home
          </.link>
          <h1 class="text-2xl sm:text-3xl font-bold text-base-content">Interactive Demo</h1>
          <p class="mt-2 text-base-content/60">
            Upload a DDEX XML file or use our sample deliveries to see the service in action.
          </p>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 sm:gap-8">
          <%!-- Left Column: Upload + Processing --%>
          <div class="space-y-6">
            <%!-- Upload Panel --%>
            <div class="card bg-base-100 shadow-md">
              <div class="card-body">
                <h2 class="card-title text-lg">
                  <.icon name="hero-cloud-arrow-up" class="size-5 text-primary" />
                  Upload Delivery
                </h2>

                <div :if={!@delivery}>
                  <%!-- Upload Mode Toggle --%>
                  <div class="flex gap-2 mb-4">
                    <button
                      phx-click="switch_upload_mode"
                      phx-value-mode="single"
                      class={["btn btn-sm flex-1", @upload_mode == :single && "btn-primary" || "btn-ghost"]}
                    >
                      <.icon name="hero-document" class="size-4" />
                      Single XML
                    </button>
                    <button
                      phx-click="switch_upload_mode"
                      phx-value-mode="package"
                      class={["btn btn-sm flex-1", @upload_mode == :package && "btn-primary" || "btn-ghost"]}
                    >
                      <.icon name="hero-folder" class="size-4" />
                      Full Package
                    </button>
                  </div>

                  <%!-- Single XML Upload --%>
                  <div :if={@upload_mode == :single}>
                    <form id="upload-form" phx-submit="upload_xml" phx-change="validate_upload" class="space-y-4">
                      <div
                        class="border-2 border-dashed border-base-300 rounded-lg p-6 sm:p-8 text-center hover:border-primary/50 transition-colors"
                        phx-drop-target={@uploads.xml_file.ref}
                      >
                        <.icon name="hero-document-arrow-up" class="size-10 text-base-content/20 mx-auto mb-3" />
                        <p class="text-sm text-base-content/60 mb-2">
                          Drag & drop your DDEX XML file here
                        </p>
                        <.live_file_input upload={@uploads.xml_file} class="file-input file-input-bordered file-input-sm w-full max-w-xs" />
                      </div>

                      <div :for={entry <- @uploads.xml_file.entries} class="flex items-center gap-2 text-sm">
                        <.icon name="hero-document" class="size-4 text-primary" />
                        <span class="flex-1 truncate">{entry.client_name}</span>
                        <span class="text-base-content/50">{format_bytes(entry.client_size)}</span>
                      </div>

                      <button
                        type="submit"
                        class="btn btn-primary w-full"
                        disabled={@uploads.xml_file.entries == []}
                      >
                        <.icon name="hero-arrow-up-tray" class="size-4" />
                        Upload & Process
                      </button>
                    </form>
                  </div>

                  <%!-- Package Upload (Multi-file) --%>
                  <div :if={@upload_mode == :package}>
                    <form id="package-upload-form" phx-submit="upload_package" phx-change="validate_upload" class="space-y-4">
                      <div
                        class="border-2 border-dashed border-base-300 rounded-lg p-6 sm:p-8 text-center hover:border-primary/50 transition-colors"
                        phx-drop-target={@uploads.package_files.ref}
                      >
                        <.icon name="hero-folder-arrow-down" class="size-10 text-base-content/20 mx-auto mb-3" />
                        <p class="text-sm text-base-content/60 mb-2">
                          Drag & drop XML + audio + artwork files
                        </p>
                        <p class="text-xs text-base-content/40 mb-3">
                          Include your DDEX XML metadata and any resource files (FLAC, WAV, MP3, JPG, PNG)
                        </p>
                        <.live_file_input upload={@uploads.package_files} class="file-input file-input-bordered file-input-sm w-full max-w-xs" />
                      </div>

                      <div :if={@uploads.package_files.entries != []} class="space-y-1">
                        <p class="text-xs text-base-content/50 font-semibold">
                          {length(@uploads.package_files.entries)} files selected
                        </p>
                        <div :for={entry <- @uploads.package_files.entries} class="flex items-center gap-2 text-sm">
                          <.icon name={file_type_icon(entry.client_name)} class={["size-4", file_type_color(entry.client_name)]} />
                          <span class="flex-1 truncate">{entry.client_name}</span>
                          <span class="badge badge-xs">{file_type_label(entry.client_name)}</span>
                          <span class="text-base-content/50">{format_bytes(entry.client_size)}</span>
                        </div>
                      </div>

                      <button
                        type="submit"
                        class="btn btn-primary w-full"
                        disabled={@uploads.package_files.entries == [] or not has_xml_file?(@uploads.package_files.entries)}
                      >
                        <.icon name="hero-arrow-up-tray" class="size-4" />
                        Upload Package & Process
                      </button>

                      <p :if={@uploads.package_files.entries != [] and not has_xml_file?(@uploads.package_files.entries)} class="text-xs text-warning text-center">
                        Please include at least one XML metadata file
                      </p>
                    </form>
                  </div>

                  <div class="divider text-xs">OR USE A SAMPLE</div>

                  <p class="text-xs text-base-content/40 mb-2">Basic fixtures</p>
                  <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <button phx-click="use_sample" phx-value-version="ern382" class="btn btn-outline btn-secondary btn-sm">
                      <.icon name="hero-beaker" class="size-4" />
                      <span class="flex flex-col items-start leading-tight">
                        <span class="text-xs font-normal opacity-70">ERN 3.8.2</span>
                        <span>Album &middot; 10 tracks</span>
                      </span>
                    </button>
                    <button phx-click="use_sample" phx-value-version="ern43" class="btn btn-outline btn-accent btn-sm">
                      <.icon name="hero-beaker" class="size-4" />
                      <span class="flex flex-col items-start leading-tight">
                        <span class="text-xs font-normal opacity-70">ERN 4.3</span>
                        <span>Single &middot; 2 tracks</span>
                      </span>
                    </button>
                  </div>

                  <p class="text-xs text-base-content/40 mt-4 mb-2">Full delivery packages</p>
                  <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
                    <button phx-click="use_sample" phx-value-version="glass_garden" class="btn btn-outline btn-primary btn-sm">
                      <.icon name="hero-musical-note" class="size-4" />
                      <span class="flex flex-col items-start leading-tight">
                        <span class="text-xs font-normal opacity-70">ERN 4.3</span>
                        <span>Album &middot; 8 tracks</span>
                      </span>
                    </button>
                    <button phx-click="use_sample" phx-value-version="copper_sun" class="btn btn-outline btn-secondary btn-sm">
                      <.icon name="hero-musical-note" class="size-4" />
                      <span class="flex flex-col items-start leading-tight">
                        <span class="text-xs font-normal opacity-70">ERN 3.8.2</span>
                        <span>Single &middot; 2 tracks</span>
                      </span>
                    </button>
                    <button phx-click="use_sample" phx-value-version="night_market" class="btn btn-outline btn-accent btn-sm">
                      <.icon name="hero-musical-note" class="size-4" />
                      <span class="flex flex-col items-start leading-tight">
                        <span class="text-xs font-normal opacity-70">ERN 4.3</span>
                        <span>EP &middot; 5 tracks</span>
                      </span>
                    </button>
                  </div>
                </div>

                <div :if={@delivery} class="text-center py-4">
                  <div class="badge badge-primary badge-lg gap-2">
                    <.icon name="hero-document" class="size-4" />
                    {@delivery.original_filename}
                  </div>
                  <div :if={!@processing} class="flex items-center justify-center gap-2 mt-3">
                    <.link
                      :if={@release}
                      href={~p"/demo/csv/#{@delivery.id}"}
                      class="btn btn-outline btn-primary btn-sm"
                    >
                      <.icon name="hero-arrow-down-tray" class="size-4" />
                      Download CSV
                    </.link>
                    <button phx-click="reset" class="btn btn-ghost btn-sm">
                      <.icon name="hero-arrow-path" class="size-4" />
                      Start over
                    </button>
                  </div>
                </div>
              </div>
            </div>

            <%!-- Processing Status --%>
            <div :if={@status_steps != []} class="card bg-base-100 shadow-md">
              <div class="card-body">
                <h2 class="card-title text-lg">
                  <.icon name="hero-cog-6-tooth" class={["size-5 text-secondary", @processing && "animate-spin"]} />
                  Processing Pipeline
                </h2>

                <ul class="steps steps-vertical">
                  <li :for={step <- @status_steps} class={step_class(step.status)}>
                    <span class="text-sm">{step.label}</span>
                  </li>
                  <li :if={@processing} class="step">
                    <span class="text-sm text-base-content/50 flex items-center gap-2">
                      <span class="loading loading-dots loading-xs"></span>
                      Working...
                    </span>
                  </li>
                </ul>
              </div>
            </div>
          </div>

          <%!-- Right Column: Results --%>
          <div>
            <div :if={@error} class="alert alert-error mb-6">
              <.icon name="hero-exclamation-triangle" class="size-5" />
              <div>
                <p class="font-semibold">Processing failed</p>
                <p class="text-sm">{@error}</p>
              </div>
              <button phx-click="reset" class="btn btn-ghost btn-sm">Try again</button>
            </div>

            <div :if={@release} class="space-y-6">
              <%!-- Release Card --%>
              <div class="card bg-base-100 shadow-md">
                <div class="card-body">
                  <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-2">
                    <div>
                      <div class="flex items-center gap-2 mb-2">
                        <span class="badge badge-primary">{format_release_type(@release.release_type)}</span>
                        <span :if={@delivery && @delivery.ern_version} class="badge badge-outline badge-sm">
                          ERN {@delivery.ern_version}
                        </span>
                        <span :if={@delivery && @delivery.source == :sftp} class="badge badge-secondary badge-sm">
                          SFTP
                        </span>
                      </div>
                      <h2 class="card-title text-xl">{@release.title}</h2>
                      <p class="text-base-content/60">{@release.display_artist}</p>
                    </div>
                    <div class="text-sm text-base-content/50 sm:text-right">
                      <p :if={@release.upc}>UPC: <span class="font-mono">{@release.upc}</span></p>
                      <p :if={@release.release_date}>{@release.release_date}</p>
                    </div>
                  </div>

                  <div class="grid grid-cols-3 gap-3 sm:gap-4 mt-4">
                    <div class="stat bg-base-200/50 rounded-box p-3">
                      <div class="stat-title text-xs">Tracks</div>
                      <div class="stat-value text-lg">{length(@tracks)}</div>
                    </div>
                    <div class="stat bg-base-200/50 rounded-box p-3">
                      <div class="stat-title text-xs">Duration</div>
                      <div class="stat-value text-lg">{format_duration(@release.duration)}</div>
                    </div>
                    <div class="stat bg-base-200/50 rounded-box p-3">
                      <div class="stat-title text-xs">Label</div>
                      <div class="stat-value text-sm truncate">{@release.label && @release.label.name}</div>
                    </div>
                  </div>
                </div>
              </div>

              <%!-- Tabs --%>
              <div role="tablist" class="tabs tabs-boxed bg-base-200">
                <button
                  role="tab"
                  class={["tab", @current_tab == "parsed" && "tab-active"]}
                  phx-click="switch_tab"
                  phx-value-tab="parsed"
                >
                  Parsed Data
                </button>
                <button
                  role="tab"
                  class={["tab", @current_tab == "json_api" && "tab-active"]}
                  phx-click="switch_tab"
                  phx-value-tab="json_api"
                >
                  JSON:API
                </button>
                <button
                  role="tab"
                  class={["tab", @current_tab == "graphql" && "tab-active"]}
                  phx-click="switch_tab"
                  phx-value-tab="graphql"
                >
                  GraphQL
                </button>
                <button
                  role="tab"
                  class={["tab", @current_tab == "csv" && "tab-active"]}
                  phx-click="switch_tab"
                  phx-value-tab="csv"
                >
                  CSV
                </button>
              </div>

              <%!-- Tab: Parsed Data --%>
              <div :if={@current_tab == "parsed"} class="card bg-base-100 shadow-md">
                <div class="card-body p-0">
                  <div class="overflow-x-auto">
                    <table class="table table-sm">
                      <thead>
                        <tr>
                          <th class="w-10">#</th>
                          <th>Title</th>
                          <th class="hidden sm:table-cell">ISRC</th>
                          <th>Artist</th>
                          <th class="w-16">Duration</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr :for={track <- @tracks} class="hover">
                          <td class="text-base-content/50">{track.track_number}</td>
                          <td class="font-medium">{track.title}</td>
                          <td class="font-mono text-xs hidden sm:table-cell">{track.isrc}</td>
                          <td class="text-base-content/70 text-sm">{track.display_artist}</td>
                          <td class="text-base-content/50 text-sm">{format_duration(track.duration)}</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>

              <%!-- Tab: JSON:API --%>
              <div :if={@current_tab == "json_api"} class="space-y-4">
                <div class="card bg-base-100 shadow-md">
                  <div class="card-body">
                    <p class="text-sm text-base-content/60 mb-1">
                      This is what your API consumers see. Try it yourself:
                    </p>
                    <div class="mockup-code text-xs">
                      <pre data-prefix="$"><code>curl {DdexDeliveryServiceWeb.Endpoint.url()}/api/json/releases/{@release.id}?include=tracks,artists,label</code></pre>
                    </div>
                  </div>
                </div>
                <div class="card bg-base-100 shadow-md">
                  <div class="card-body">
                    <div class="flex items-center justify-between mb-2">
                      <h3 class="font-semibold text-sm">Response preview</h3>
                      <span class="badge badge-outline badge-xs">application/vnd.api+json</span>
                    </div>
                    <pre class="bg-base-200 rounded-lg p-4 overflow-auto text-xs max-h-96"><code>{json_api_example(@release, @tracks)}</code></pre>
                  </div>
                </div>
              </div>

              <%!-- Tab: GraphQL --%>
              <div :if={@current_tab == "graphql"} class="space-y-4">
                <div class="card bg-base-100 shadow-md">
                  <div class="card-body">
                    <p class="text-sm text-base-content/60 mb-1">
                      Query your catalog with GraphQL. Open the
                      <a href="/gql/playground" target="_blank" class="link link-primary">playground</a>
                      to try it live.
                    </p>
                    <pre class="bg-base-200 rounded-lg p-4 overflow-auto text-xs max-h-96"><code>{graphql_example(@release.id)}</code></pre>
                  </div>
                </div>
              </div>

              <%!-- Tab: CSV --%>
              <div :if={@current_tab == "csv"} class="space-y-4">
                <div class="card bg-base-100 shadow-md">
                  <div class="card-body">
                    <p class="text-sm text-base-content/60 mb-1">
                      Export delivery data as CSV for spreadsheet tools or downstream systems.
                    </p>
                    <div class="mockup-code text-xs">
                      <pre data-prefix="$"><code>curl {DdexDeliveryServiceWeb.Endpoint.url()}/api/csv/deliveries/{@delivery.id}/tracks -H "Authorization: Bearer dds_..."</code></pre>
                    </div>
                  </div>
                </div>
                <div class="card bg-base-100 shadow-md">
                  <div class="card-body">
                    <div class="flex items-center justify-between mb-2">
                      <h3 class="font-semibold text-sm">Download</h3>
                      <span class="badge badge-outline badge-xs">text/csv</span>
                    </div>
                    <div class="flex gap-3">
                      <.link
                        href={~p"/demo/csv/#{@delivery.id}"}
                        class="btn btn-primary btn-sm"
                      >
                        <.icon name="hero-arrow-down-tray" class="size-4" />
                        Tracks CSV
                      </.link>
                    </div>
                  </div>
                </div>
              </div>

              <%!-- API messaging --%>
              <div class="text-center py-4">
                <p class="text-sm text-base-content/40">
                  This is what your API consumers get &mdash; clean, structured data from any DDEX delivery.
                </p>
              </div>
            </div>

            <%!-- Empty State --%>
            <div :if={!@release && !@processing && !@error} class="card bg-base-100 shadow-md">
              <div class="card-body items-center text-center py-12 sm:py-16">
                <.icon name="hero-musical-note" class="size-16 text-base-content/10 mb-4" />
                <h3 class="text-lg font-semibold text-base-content/40">No delivery yet</h3>
                <p class="text-sm text-base-content/30 max-w-xs">
                  Upload a DDEX XML file or use one of the sample deliveries to get started.
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp step_class(:done), do: "step step-primary"
  defp step_class(:error), do: "step step-error"
  defp step_class(_), do: "step"

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_duration(nil), do: "-"

  defp format_duration(seconds) when is_integer(seconds) do
    mins = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{mins}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end

  defp format_release_type(:album), do: "Album"
  defp format_release_type(:single), do: "Single"
  defp format_release_type(:ep), do: "EP"
  defp format_release_type(:compilation), do: "Compilation"
  defp format_release_type(_), do: "Release"

  defp file_type_icon(filename) do
    cond do
      String.ends_with?(filename, ".xml") -> "hero-document-text"
      audio_file?(filename) -> "hero-musical-note"
      image_file?(filename) -> "hero-photo"
      true -> "hero-document"
    end
  end

  defp file_type_color(filename) do
    cond do
      String.ends_with?(filename, ".xml") -> "text-primary"
      audio_file?(filename) -> "text-secondary"
      image_file?(filename) -> "text-accent"
      true -> "text-base-content/50"
    end
  end

  defp file_type_label(filename) do
    cond do
      String.ends_with?(filename, ".xml") -> "XML"
      audio_file?(filename) -> "Audio"
      image_file?(filename) -> "Artwork"
      true -> "File"
    end
  end

  defp audio_file?(filename) do
    ext = Path.extname(filename) |> String.downcase()
    ext in ~w(.flac .wav .mp3 .aac .ogg)
  end

  defp image_file?(filename) do
    ext = Path.extname(filename) |> String.downcase()
    ext in ~w(.jpg .jpeg .png .tiff .tif)
  end

  defp has_xml_file?(entries) do
    Enum.any?(entries, fn entry -> String.ends_with?(entry.client_name, ".xml") end)
  end

  defp json_api_example(release, tracks) do
    artists =
      case release.artists do
        %Ash.NotLoaded{} -> []
        list -> list
      end

    data = %{
      "data" => %{
        "id" => release.id,
        "type" => "release",
        "attributes" => %{
          "title" => release.title,
          "upc" => release.upc,
          "release-type" => to_string(release.release_type),
          "release-date" => to_string(release.release_date),
          "display-artist" => release.display_artist,
          "duration" => release.duration
        },
        "relationships" => %{
          "tracks" => %{
            "data" =>
              Enum.map(tracks, fn t ->
                %{"id" => t.id, "type" => "track"}
              end)
          },
          "artists" => %{
            "data" =>
              Enum.map(artists, fn a ->
                %{"id" => a.id, "type" => "artist"}
              end)
          }
        }
      },
      "included" =>
        Enum.map(tracks, fn t ->
          %{
            "id" => t.id,
            "type" => "track",
            "attributes" => %{
              "title" => t.title,
              "isrc" => t.isrc,
              "track-number" => t.track_number,
              "duration" => t.duration,
              "display-artist" => t.display_artist
            }
          }
        end) ++
          Enum.map(artists, fn a ->
            %{
              "id" => a.id,
              "type" => "artist",
              "attributes" => %{
                "name" => a.name
              }
            }
          end)
    }

    Jason.encode!(data, pretty: true)
  end

  defp graphql_example(release_id) do
    query = ~S"""
    query {
      getRelease(id: "RELEASE_ID") {
        id
        title
        upc
        releaseType
        displayArtist
        releaseDate
        duration
        label {
          name
        }
        artists {
          name
        }
        tracks {
          trackNumber
          title
          isrc
          duration
          displayArtist
        }
        deals {
          commercialModel
          usageTypes
          territoryCodes
          startDate
        }
      }
    }
    """

    String.replace(query, "RELEASE_ID", release_id)
  end
end
