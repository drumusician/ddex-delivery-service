defmodule DdexDeliveryService.Ingestion.Ern43Test do
  use DdexDeliveryService.DataCase, async: true

  alias DdexDeliveryService.Parser
  alias DdexDeliveryService.Ingestion
  alias DdexDeliveryService.Ingestion.Persister
  alias DdexDeliveryService.Catalog

  @fixtures_path "priv/ddex/fixtures"

  defp system_actor, do: %DdexDeliveryService.Accounts.SystemActor{}

  setup do
    org = create_test_org!()
    tenant = org.id

    xml = File.read!(Path.join(@fixtures_path, "sample_single_ern43.xml"))
    {:ok, message} = Parser.parse(xml)

    {:ok, delivery} =
      Ingestion.create_delivery(
        %{source: :upload, status: :received, original_filename: "sample_single_ern43.xml"},
        actor: system_actor(),
        tenant: tenant
      )

    %{message: message, delivery: delivery, tenant: tenant}
  end

  describe "ERN 4.3 persist/3" do
    test "creates the main release", %{message: message, delivery: delivery, tenant: tenant} do
      {:ok, release} = Persister.persist(message, delivery.id, tenant)

      assert release.title == "Tangerine Skies"
      assert release.release_type == :single
      assert release.upc == "0196118275463"
      assert release.release_date == ~D[2025-03-14]
      assert release.display_artist == "Luma Vasquez"
    end

    test "creates tracks", %{message: message, delivery: delivery, tenant: tenant} do
      {:ok, release} = Persister.persist(message, delivery.id, tenant)

      tracks =
        Catalog.list_tracks!(
          query: [filter: [release_id: release.id], sort: [track_number: :asc]],
          actor: system_actor(),
          tenant: tenant
        )

      assert length(tracks) == 2

      first = hd(tracks)
      assert first.title == "Tangerine Skies"
      assert first.isrc == "USA402500101"

      second = Enum.at(tracks, 1)
      assert second.title == "Tangerine Skies (Kael Torres Remix)"
      assert second.isrc == "USA402500102"
    end

    test "creates artists with correct roles", %{message: message, delivery: delivery, tenant: tenant} do
      {:ok, release} = Persister.persist(message, delivery.id, tenant)

      tracks =
        Catalog.list_tracks!(
          query: [filter: [release_id: release.id], sort: [track_number: :asc]],
          actor: system_actor(),
          tenant: tenant
        )

      # Track 2 has 2 artists (main + remixer)
      track2 = Enum.at(tracks, 1)
      track2 = Ash.load!(track2, :artists, actor: system_actor(), tenant: tenant)
      assert length(track2.artists) == 2
      artist_names = Enum.map(track2.artists, & &1.name) |> Enum.sort()
      assert artist_names == ["Kael Torres", "Luma Vasquez"]
    end

    test "creates deals with subscription model", %{message: message, delivery: delivery, tenant: tenant} do
      {:ok, release} = Persister.persist(message, delivery.id, tenant)

      release = Ash.load!(release, :deals, actor: system_actor(), tenant: tenant)
      assert length(release.deals) == 1

      deal = hd(release.deals)
      assert deal.commercial_model == "SubscriptionModel"
      assert "OnDemandStream" in deal.usage_types
      assert deal.start_date == ~D[2025-03-14]
    end

    test "creates label", %{message: message, delivery: delivery, tenant: tenant} do
      {:ok, release} = Persister.persist(message, delivery.id, tenant)

      release = Ash.load!(release, :label, actor: system_actor(), tenant: tenant)
      assert release.label.name == "Moonfield Records"
    end
  end
end
