defmodule DdexDeliveryService.SFTP.FileWatcher do
  @moduledoc """
  GenServer that watches for BatchComplete manifest files.

  Triggered in two ways:
  1. Directly by the SFTP file handler when a BatchComplete file is written
  2. Periodic scan (every 60s) as a safety net for edge cases

  On trigger, it:
  1. Finds the XML metadata file in the batch directory
  2. Reads the XML content
  3. Inventories resource files (audio, artwork)
  4. Calls `Ingest.ingest_package/4`
  5. Moves the batch directory to a processed/ folder
  """

  use GenServer
  require Logger

  alias DdexDeliveryService.Ingestion.Ingest
  alias DdexDeliveryService.SFTP.FileHandler

  @scan_interval :timer.seconds(60)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Called by the SFTP file handler when a BatchComplete file is detected.
  """
  def batch_complete(org_slug, batch_dir) do
    GenServer.cast(__MODULE__, {:batch_complete, org_slug, batch_dir})
  end

  @impl true
  def init(_opts) do
    schedule_scan()
    {:ok, %{processed: MapSet.new()}}
  end

  @impl true
  def handle_cast({:batch_complete, org_slug, batch_dir}, state) do
    if MapSet.member?(state.processed, batch_dir) do
      {:noreply, state}
    else
      process_batch(org_slug, batch_dir)
      {:noreply, %{state | processed: MapSet.put(state.processed, batch_dir)}}
    end
  end

  @impl true
  def handle_info(:scan, state) do
    state = scan_for_batches(state)
    schedule_scan()
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp schedule_scan do
    Process.send_after(self(), :scan, @scan_interval)
  end

  defp scan_for_batches(state) do
    root = FileHandler.upload_root()

    if File.dir?(root) do
      root
      |> File.ls!()
      |> Enum.reduce(state, fn org_slug, acc ->
        org_dir = Path.join(root, org_slug)

        if File.dir?(org_dir) and org_slug != "processed" do
          scan_org_dir(org_slug, org_dir, acc)
        else
          acc
        end
      end)
    else
      state
    end
  end

  defp scan_org_dir(org_slug, org_dir, state) do
    org_dir
    |> File.ls!()
    |> Enum.reduce(state, fn batch_id, acc ->
      batch_dir = Path.join(org_dir, batch_id)

      if File.dir?(batch_dir) and batch_id != "processed" and
           not MapSet.member?(acc.processed, batch_dir) do
        # Check for BatchComplete file
        if has_batch_complete?(batch_dir) do
          process_batch(org_slug, batch_dir)
          %{acc | processed: MapSet.put(acc.processed, batch_dir)}
        else
          acc
        end
      else
        acc
      end
    end)
  end

  defp has_batch_complete?(batch_dir) do
    batch_dir
    |> File.ls!()
    |> Enum.any?(&FileHandler.batch_complete?/1)
  end

  defp process_batch(org_slug, batch_dir) do
    Logger.info("Processing batch: org=#{org_slug} dir=#{batch_dir}")

    with {:ok, org} <- lookup_org(org_slug),
         {:ok, xml_file, xml_content} <- find_xml_metadata(batch_dir),
         resource_files <- inventory_resources(batch_dir, xml_file) do
      {:ok, delivery} = Ingest.ingest_package(xml_content, resource_files, org.id, Path.basename(xml_file))
      Logger.info("Batch ingested: delivery=#{delivery.id} org=#{org_slug}")
      move_to_processed(batch_dir)
    else
      {:error, reason} ->
        Logger.error("Batch processing failed: org=#{org_slug} dir=#{batch_dir} error=#{inspect(reason)}")
    end
  end

  defp lookup_org(org_slug) do
    actor = %DdexDeliveryService.Accounts.SystemActor{}

    case DdexDeliveryService.Accounts.get_organization_by_slug(org_slug, actor: actor) do
      {:ok, org} -> {:ok, org}
      _ -> {:error, "Organization not found: #{org_slug}"}
    end
  end

  defp find_xml_metadata(batch_dir) do
    xml_files =
      batch_dir
      |> File.ls!()
      |> Enum.filter(fn name ->
        String.ends_with?(name, ".xml") and not FileHandler.batch_complete?(name)
      end)

    case xml_files do
      [xml_file | _] ->
        full_path = Path.join(batch_dir, xml_file)
        content = File.read!(full_path)
        {:ok, full_path, content}

      [] ->
        {:error, "No XML metadata file found in #{batch_dir}"}
    end
  end

  defp inventory_resources(batch_dir, xml_file) do
    xml_basename = Path.basename(xml_file)

    batch_dir
    |> list_files_recursive()
    |> Enum.reject(fn path ->
      basename = Path.basename(path)
      basename == xml_basename or FileHandler.batch_complete?(basename)
    end)
    |> Enum.map(fn path ->
      %{
        path: path,
        filename: Path.basename(path),
        content_type: detect_content_type(path)
      }
    end)
  end

  defp list_files_recursive(dir) do
    dir
    |> File.ls!()
    |> Enum.flat_map(fn entry ->
      full_path = Path.join(dir, entry)

      if File.dir?(full_path) do
        list_files_recursive(full_path)
      else
        [full_path]
      end
    end)
  end

  defp detect_content_type(path) do
    case Path.extname(path) |> String.downcase() do
      ".flac" -> "audio/flac"
      ".wav" -> "audio/wav"
      ".mp3" -> "audio/mpeg"
      ".aac" -> "audio/aac"
      ".ogg" -> "audio/ogg"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".tiff" -> "image/tiff"
      ".tif" -> "image/tiff"
      ".pdf" -> "application/pdf"
      ".xml" -> "application/xml"
      _ -> "application/octet-stream"
    end
  end

  defp move_to_processed(batch_dir) do
    parent = Path.dirname(batch_dir)
    batch_name = Path.basename(batch_dir)
    processed_dir = Path.join(parent, "processed")
    File.mkdir_p!(processed_dir)
    dest = Path.join(processed_dir, batch_name)

    case File.rename(batch_dir, dest) do
      :ok ->
        Logger.info("Batch moved to processed: #{dest}")

      {:error, reason} ->
        Logger.warning("Could not move batch to processed: #{inspect(reason)}")
    end
  end
end
