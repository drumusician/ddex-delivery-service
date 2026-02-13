defmodule DdexDeliveryServiceWeb.DashboardLive do
  use DdexDeliveryServiceWeb, :live_view

  alias DdexDeliveryService.Catalog
  alias DdexDeliveryService.Ingestion

  defp system_actor, do: %DdexDeliveryService.Accounts.SystemActor{}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(DdexDeliveryService.PubSub, "delivery:*")
    end

    org = get_or_create_demo_org()
    {:ok, socket |> assign(page_title: "Dashboard", org_id: org.id) |> load_data()}
  end

  defp get_or_create_demo_org do
    case DdexDeliveryService.Accounts.get_organization_by_slug("demo", actor: system_actor()) do
      {:ok, org} -> org
      _ ->
        {:ok, org} = DdexDeliveryService.Accounts.create_organization(
          %{name: "Demo Organization", slug: "demo"},
          actor: system_actor()
        )
        org
    end
  end

  @impl true
  def handle_info({:delivery_status, _}, socket) do
    {:noreply, load_data(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp load_data(socket) do
    actor = system_actor()
    tenant = socket.assigns.org_id

    deliveries =
      Ingestion.list_deliveries!(
        query: [sort: [inserted_at: :desc], limit: 10],
        actor: actor,
        tenant: tenant
      )

    releases =
      Catalog.list_releases!(
        query: [sort: [inserted_at: :desc], limit: 5],
        actor: actor,
        tenant: tenant
      )

    release_count = length(Catalog.list_releases!(actor: actor, tenant: tenant))
    track_count = length(Catalog.list_tracks!(actor: actor, tenant: tenant))
    # Artists are global, no tenant needed
    artist_count = length(Catalog.list_artists!(actor: actor))

    assign(socket,
      deliveries: deliveries,
      recent_releases: releases,
      release_count: release_count,
      track_count: track_count,
      artist_count: artist_count
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl px-6 py-12">
      <div class="mb-10">
        <h1 class="text-3xl font-bold text-base-content">Dashboard</h1>
        <p class="mt-2 text-base-content/60">
          Overview of your DDEX delivery pipeline.
        </p>
      </div>

      <%!-- Stats --%>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-10">
        <div class="stat bg-base-100 shadow-md rounded-box">
          <div class="stat-figure text-primary">
            <.icon name="hero-inbox-stack" class="size-8" />
          </div>
          <div class="stat-title">Deliveries</div>
          <div class="stat-value text-primary">{length(@deliveries)}</div>
        </div>

        <div class="stat bg-base-100 shadow-md rounded-box">
          <div class="stat-figure text-secondary">
            <.icon name="hero-musical-note" class="size-8" />
          </div>
          <div class="stat-title">Releases</div>
          <div class="stat-value text-secondary">{@release_count}</div>
        </div>

        <div class="stat bg-base-100 shadow-md rounded-box">
          <div class="stat-figure text-accent">
            <.icon name="hero-play" class="size-8" />
          </div>
          <div class="stat-title">Tracks</div>
          <div class="stat-value text-accent">{@track_count}</div>
        </div>

        <div class="stat bg-base-100 shadow-md rounded-box">
          <div class="stat-figure text-info">
            <.icon name="hero-user-group" class="size-8" />
          </div>
          <div class="stat-title">Artists</div>
          <div class="stat-value text-info">{@artist_count}</div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
        <%!-- Recent Deliveries --%>
        <div class="card bg-base-100 shadow-md">
          <div class="card-body">
            <h2 class="card-title">
              <.icon name="hero-inbox-stack" class="size-5 text-primary" />
              Recent Deliveries
            </h2>

            <div :if={@deliveries == []} class="py-8 text-center text-base-content/40">
              <p>No deliveries yet.</p>
              <.link navigate={~p"/demo"} class="btn btn-primary btn-sm mt-3">
                Try the demo
              </.link>
            </div>

            <div :if={@deliveries != []} class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>File</th>
                    <th>Status</th>
                    <th>ERN</th>
                    <th>Time</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={delivery <- @deliveries} class="hover">
                    <td class="font-medium truncate max-w-[200px]">
                      {delivery.original_filename || "—"}
                    </td>
                    <td>
                      <span class={["badge badge-sm", status_badge(delivery.status)]}>
                        {delivery.status}
                      </span>
                    </td>
                    <td class="text-base-content/50 text-xs">
                      {delivery.ern_version || "—"}
                    </td>
                    <td class="text-base-content/50 text-xs">
                      {format_time(delivery.inserted_at)}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <%!-- Recent Releases --%>
        <div class="card bg-base-100 shadow-md">
          <div class="card-body">
            <h2 class="card-title">
              <.icon name="hero-musical-note" class="size-5 text-secondary" />
              Recent Releases
            </h2>

            <div :if={@recent_releases == []} class="py-8 text-center text-base-content/40">
              <p>No releases in catalog yet.</p>
            </div>

            <div :if={@recent_releases != []} class="space-y-3">
              <div
                :for={release <- @recent_releases}
                class="flex items-center gap-3 p-3 rounded-lg bg-base-200/50"
              >
                <div class="w-10 h-10 rounded bg-primary/10 flex items-center justify-center flex-shrink-0">
                  <.icon name="hero-musical-note" class="size-5 text-primary" />
                </div>
                <div class="flex-1 min-w-0">
                  <p class="font-medium truncate">{release.title}</p>
                  <p class="text-sm text-base-content/50 truncate">{release.display_artist}</p>
                </div>
                <div class="text-right flex-shrink-0">
                  <div class="badge badge-outline badge-sm">{format_release_type(release.release_type)}</div>
                  <p class="text-xs text-base-content/40 mt-1">{release.upc}</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Quick Links --%>
      <div class="mt-8 card bg-base-100 shadow-md">
        <div class="card-body">
          <h2 class="card-title">
            <.icon name="hero-link" class="size-5" />
            Quick Links
          </h2>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 mt-2">
            <a href="/api/json/swaggerui" target="_blank" class="btn btn-outline btn-sm gap-2">
              <.icon name="hero-code-bracket" class="size-4" />
              REST API (Swagger)
            </a>
            <a href="/gql/playground" target="_blank" class="btn btn-outline btn-sm gap-2">
              <.icon name="hero-command-line" class="size-4" />
              GraphQL Playground
            </a>
            <.link navigate={~p"/demo"} class="btn btn-outline btn-sm gap-2">
              <.icon name="hero-beaker" class="size-4" />
              Interactive Demo
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp status_badge(:received), do: "badge-info"
  defp status_badge(:processing), do: "badge-warning"
  defp status_badge(:completed), do: "badge-success"
  defp status_badge(:failed), do: "badge-error"
  defp status_badge(_), do: ""

  defp format_release_type(:album), do: "Album"
  defp format_release_type(:single), do: "Single"
  defp format_release_type(:ep), do: "EP"
  defp format_release_type(:compilation), do: "Compilation"
  defp format_release_type(_), do: "Release"

  defp format_time(nil), do: "—"

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%b %d, %H:%M")
  end
end
