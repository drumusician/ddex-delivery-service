defmodule DdexDeliveryService.Ingestion.Ingest do
  @moduledoc """
  Entry point for ingesting DDEX deliveries.

  Provides functions for the demo/upload flow:
  - Create a delivery record
  - Enqueue the processing worker
  - Use sample fixture data
  """

  alias DdexDeliveryService.Ingestion
  alias DdexDeliveryService.Workers.ProcessDeliveryWorker

  defp system_actor, do: %DdexDeliveryService.Accounts.SystemActor{}

  @samples %{
    "ern382" => {"priv/ddex/fixtures/sample_album_ern382.xml", "sample_album_ern382.xml"},
    "ern43" => {"priv/ddex/fixtures/sample_single_ern43.xml", "sample_single_ern43.xml"},
    "glass_garden" => {"priv/ddex/packages/glass_garden_ern43/glass_garden.xml", "glass_garden.xml"},
    "copper_sun" => {"priv/ddex/packages/copper_sun_ern382/copper_sun.xml", "copper_sun.xml"},
    "night_market" => {"priv/ddex/packages/night_market_ern43/night_market.xml", "night_market.xml"}
  }

  @doc """
  Ingest an XML string. Creates a delivery and enqueues processing.
  Returns `{:ok, delivery}`.

  Requires `organization_id` to scope the delivery to a tenant.
  """
  def ingest_xml(xml_string, organization_id, filename \\ "upload.xml") do
    {:ok, delivery} =
      Ingestion.create_delivery(
        %{
          source: :upload,
          status: :received,
          original_filename: filename
        },
        actor: system_actor(),
        tenant: organization_id
      )

    %{delivery_id: delivery.id, xml: xml_string, organization_id: organization_id}
    |> ProcessDeliveryWorker.new()
    |> Oban.insert!()

    {:ok, delivery}
  end

  @doc """
  Ingest a bundled sample fixture.

  ## Options

    * `"ern382"` - ERN 3.8.2 album (10 tracks) - default
    * `"ern43"` - ERN 4.3 single (2 tracks)
    * `"glass_garden"` - ERN 4.3 album (8 tracks, full package)
    * `"copper_sun"` - ERN 3.8.2 single (2 tracks, full package)
    * `"night_market"` - ERN 4.3 EP (5 tracks, full package)

  Returns `{:ok, delivery}`.
  """
  def ingest_sample(organization_id, version \\ "ern382") do
    {fixture_path, filename} = Map.fetch!(@samples, version)
    path = Application.app_dir(:ddex_delivery_service, fixture_path)
    xml = File.read!(path)
    ingest_xml(xml, organization_id, filename)
  end

  @doc """
  Ingest a full package: XML metadata + resource files (audio, artwork).

  Creates a delivery record, stores all files to S3, and enqueues processing.

  ## Parameters

    * `xml_string` - The DDEX XML content
    * `resource_files` - List of `%{path: path, filename: name, content_type: type}` maps
    * `organization_id` - The tenant org ID
    * `filename` - The XML filename

  Returns `{:ok, delivery}`.
  """
  def ingest_package(xml_string, resource_files, organization_id, filename \\ "upload.xml") do
    alias DdexDeliveryService.FileStorage

    source = if Enum.empty?(resource_files), do: :upload, else: :sftp

    {:ok, delivery} =
      Ingestion.create_delivery(
        %{
          source: source,
          status: :received,
          original_filename: filename
        },
        actor: system_actor(),
        tenant: organization_id
      )

    # Store the XML to S3
    FileStorage.store_xml(xml_string, organization_id, delivery.id, filename)

    # Store resource files to S3
    for file <- resource_files do
      FileStorage.store_file(file.path, organization_id, delivery.id, file)
    end

    # Enqueue processing
    %{delivery_id: delivery.id, xml: xml_string, organization_id: organization_id}
    |> ProcessDeliveryWorker.new()
    |> Oban.insert!()

    {:ok, delivery}
  end

  @doc """
  Returns available sample fixture keys.
  """
  def available_samples, do: Map.keys(@samples)
end
