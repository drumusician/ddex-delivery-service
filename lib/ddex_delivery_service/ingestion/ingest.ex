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
    "ern43" => {"priv/ddex/fixtures/sample_single_ern43.xml", "sample_single_ern43.xml"}
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

  Returns `{:ok, delivery}`.
  """
  def ingest_sample(organization_id, version \\ "ern382") do
    {fixture_path, filename} = Map.fetch!(@samples, version)
    path = Application.app_dir(:ddex_delivery_service, fixture_path)
    xml = File.read!(path)
    ingest_xml(xml, organization_id, filename)
  end

  @doc """
  Returns available sample fixture keys.
  """
  def available_samples, do: Map.keys(@samples)
end
