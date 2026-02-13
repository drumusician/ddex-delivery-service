defmodule DdexDeliveryService.Ingestion.PersisterTest do
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

    xml = File.read!(Path.join(@fixtures_path, "sample_album_ern382.xml"))
    {:ok, message} = Parser.parse(xml)

    # Create a delivery record
    {:ok, delivery} =
      Ingestion.create_delivery(%{
        source: :upload,
        status: :received,
        original_filename: "sample_album_ern382.xml"
      }, actor: system_actor(), tenant: tenant)

    %{message: message, delivery: delivery, tenant: tenant}
  end

  describe "persist/3" do
    test "creates the main release", %{message: message, delivery: delivery, tenant: tenant} do
      {:ok, release} = Persister.persist(message, delivery.id, tenant)

      assert release.title == "Signals from the Deep"
      assert release.release_type == :album
      assert release.upc == "5400123456789"
      assert release.release_date == ~D[2024-09-15]
      assert release.display_artist == "Aurora Waves"
      assert release.delivery_id == delivery.id
    end

    test "creates p_line and c_line", %{message: message, delivery: delivery, tenant: tenant} do
      {:ok, release} = Persister.persist(message, delivery.id, tenant)

      assert release.p_line.text == "2024 Neon Harbor Records"
      assert release.p_line.year == 2024
      assert release.c_line.text == "2024 Neon Harbor Records"
      assert release.c_line.year == 2024
    end

    test "creates the label", %{message: message, delivery: delivery, tenant: tenant} do
      {:ok, release} = Persister.persist(message, delivery.id, tenant)

      release = Ash.load!(release, :label, actor: system_actor(), tenant: tenant)
      assert release.label.name == "Neon Harbor Records"
    end

    test "creates tracks", %{message: message, delivery: delivery, tenant: tenant} do
      {:ok, release} = Persister.persist(message, delivery.id, tenant)

      tracks =
        Catalog.list_tracks!(
          query: [filter: [release_id: release.id], sort: [track_number: :asc]],
          actor: system_actor(),
          tenant: tenant
        )

      assert length(tracks) == 10

      first = hd(tracks)
      assert first.title == "Midnight Signal"
      assert first.isrc == "NLA401234501"
      assert first.duration == 252
      assert first.track_number == 1
    end

    test "creates artists and release-artist joins", %{message: message, delivery: delivery, tenant: tenant} do
      {:ok, release} = Persister.persist(message, delivery.id, tenant)

      release = Ash.load!(release, [artists: []], actor: system_actor(), tenant: tenant)
      assert length(release.artists) == 1
      assert hd(release.artists).name == "Aurora Waves"
    end

    test "creates track-artist joins", %{message: message, delivery: delivery, tenant: tenant} do
      {:ok, release} = Persister.persist(message, delivery.id, tenant)

      tracks =
        Catalog.list_tracks!(
          query: [filter: [release_id: release.id], sort: [track_number: :asc]],
          actor: system_actor(),
          tenant: tenant
        )

      # Track 5 "Vapor City" has 2 artists
      track5 = Enum.at(tracks, 4)
      track5 = Ash.load!(track5, :artists, actor: system_actor(), tenant: tenant)
      assert length(track5.artists) == 2
      artist_names = Enum.map(track5.artists, & &1.name) |> Enum.sort()
      assert artist_names == ["Aurora Waves", "Echo Module"]
    end

    test "creates deals", %{message: message, delivery: delivery, tenant: tenant} do
      {:ok, release} = Persister.persist(message, delivery.id, tenant)

      release = Ash.load!(release, :deals, actor: system_actor(), tenant: tenant)
      assert length(release.deals) == 1

      deal = hd(release.deals)
      assert deal.commercial_model == "PayAsYouGoModel"
      assert "OnDemandStream" in deal.usage_types
      assert "PermanentDownload" in deal.usage_types
      assert deal.start_date == ~D[2024-09-15]
    end

    test "creates territory releases", %{message: message, delivery: delivery, tenant: tenant} do
      {:ok, release} = Persister.persist(message, delivery.id, tenant)

      release = Ash.load!(release, :territory_releases, actor: system_actor(), tenant: tenant)
      assert length(release.territory_releases) == 1

      tr = hd(release.territory_releases)
      assert tr.territory_code == "Worldwide"
      assert tr.genre == "Electronic"
      assert tr.sub_genre == "Synthwave"
      assert tr.label_name == "Neon Harbor Records"
    end

    test "upserts artists (no duplicates across deliveries)", %{delivery: delivery, tenant: tenant} do
      # Parse and persist first delivery
      xml = File.read!(Path.join(@fixtures_path, "sample_album_ern382.xml"))
      {:ok, message} = Parser.parse(xml)
      {:ok, _} = Persister.persist(message, delivery.id, tenant)

      # Count artists after first persist (artists are global)
      artists_before = Catalog.list_artists!(actor: system_actor())
      aurora_before = Enum.count(artists_before, &(&1.name == "Aurora Waves"))
      assert aurora_before == 1

      # Upsert the same artist again directly
      Catalog.upsert_artist!(%{name: "Aurora Waves"}, actor: system_actor())

      # Should still only have one Aurora Waves
      artists_after = Catalog.list_artists!(actor: system_actor())
      aurora_after = Enum.count(artists_after, &(&1.name == "Aurora Waves"))
      assert aurora_after == 1
    end
  end
end
