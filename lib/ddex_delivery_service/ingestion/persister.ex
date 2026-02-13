defmodule DdexDeliveryService.Ingestion.Persister do
  @moduledoc """
  Maps parsed DDEX message data into Ash resource creates.

  Takes the output of `DdexDeliveryService.Parser.parse/1` and persists
  it as Catalog resources (Release, Track, Artist, Deal, TerritoryRelease).
  """

  alias DdexDeliveryService.Catalog
  alias DdexDeliveryService.Catalog.{Release, Track, ReleaseArtist, TrackArtist, Deal, TerritoryRelease}

  require Ash.Query

  defp system_actor, do: %DdexDeliveryService.Accounts.SystemActor{}
  defp opts(tenant), do: [actor: system_actor(), tenant: tenant]

  @doc """
  Persist a parsed DDEX message to the database.

  Returns `{:ok, release}` for the main release, or `{:error, reason}`.
  """
  def persist(parsed_message, delivery_id, tenant) do
    main_release = find_main_release(parsed_message.releases)

    if is_nil(main_release) do
      {:error, "No main release found in message"}
    else
      do_persist(parsed_message, main_release, delivery_id, tenant)
    end
  end

  defp do_persist(message, main_release, delivery_id, tenant) do
    dbt = main_release.details_by_territory

    # 1. Upsert label
    label = upsert_label(dbt, tenant)

    # 2. Upsert artists from main release (artists are global, no tenant)
    main_artists = upsert_artists(dbt)

    # 3. Build resource reference -> sound recording lookup
    recording_map = build_recording_map(message.sound_recordings)

    # 4. Upsert the release
    release_params = build_release_params(main_release, label, delivery_id)
    {:ok, release} = create_release(release_params, tenant)

    # 5. Create release-artist joins
    create_release_artists(release, main_artists, tenant)

    # 6. Create tracks from sound recordings
    track_refs = main_release.resource_references || []

    track_refs
    |> Enum.with_index(1)
    |> Enum.each(fn {ref, index} ->
      case Map.get(recording_map, ref) do
        nil -> :skip
        recording -> create_track_with_artists(recording, release, index, tenant)
      end
    end)

    # 7. Create deals
    create_deals(message.deals, release, main_release.release_reference, tenant)

    # 8. Create territory releases
    create_territory_releases(main_release, release, tenant)

    {:ok, release}
  end

  defp find_main_release(releases) do
    Enum.find(releases, fn r ->
      r.is_main_release == true ||
        r.release_type in ["Album", "Single", "EP", "Compilation"]
    end)
  end

  defp upsert_label(nil, _tenant), do: nil

  defp upsert_label(dbt, tenant) do
    case dbt.label_name do
      nil -> nil
      "" -> nil
      name -> Catalog.upsert_label!(%{name: name}, opts(tenant))
    end
  end

  defp upsert_artists(nil), do: []

  defp upsert_artists(dbt) do
    artists = dbt.artists || []

    Enum.map(artists, fn artist ->
      role = normalize_role(artist.role)
      # Artists are global (not tenant-scoped)
      db_artist = Catalog.upsert_artist!(%{name: artist.name}, actor: system_actor())
      {db_artist, role}
    end)
  end

  defp build_recording_map(sound_recordings) do
    Map.new(sound_recordings, fn sr -> {sr.resource_reference, sr} end)
  end

  defp build_release_params(main_release, label, delivery_id) do
    dbt = main_release.details_by_territory

    params = %{
      title: dbt && dbt.title || main_release.title,
      release_type: normalize_release_type(main_release.release_type),
      upc: main_release.icpn,
      release_date: main_release.release_date,
      duration: main_release.duration,
      display_artist: dbt && dbt.display_artist_name,
      ddex_release_reference: main_release.release_reference,
      parental_warning: normalize_parental_warning(dbt && dbt.parental_warning),
      delivery_id: delivery_id
    }

    params =
      if label do
        Map.put(params, :label_id, label.id)
      else
        params
      end

    params =
      if main_release.p_line_text && main_release.p_line_text != "" do
        Map.put(params, :p_line, %{
          year: parse_int(main_release.p_line_year),
          text: main_release.p_line_text
        })
      else
        params
      end

    if main_release.c_line_text && main_release.c_line_text != "" do
      Map.put(params, :c_line, %{
        year: parse_int(main_release.c_line_year),
        text: main_release.c_line_text
      })
    else
      params
    end
  end

  defp create_release(params, tenant) do
    Release
    |> Ash.Changeset.for_create(:upsert, params, opts(tenant))
    |> Ash.create(opts(tenant))
  end

  defp create_release_artists(release, artists, tenant) do
    artists
    |> Enum.with_index(1)
    |> Enum.each(fn {{artist, role}, seq} ->
      ReleaseArtist
      |> Ash.Changeset.for_create(
        :upsert,
        %{release_id: release.id, artist_id: artist.id, role: role, sequence_number: seq},
        opts(tenant)
      )
      |> Ash.create!(opts(tenant))
    end)
  end

  defp create_track_with_artists(recording, release, track_number, tenant) do
    track_params = %{
      title: recording.title,
      isrc: recording.isrc,
      duration: recording.duration,
      track_number: track_number,
      disc_number: 1,
      display_artist: recording.display_artist_name,
      ddex_resource_reference: recording.resource_reference,
      release_id: release.id
    }

    track_params =
      if recording.p_line_text && recording.p_line_text != "" do
        Map.put(track_params, :p_line, %{
          year: recording.p_line_year,
          text: recording.p_line_text
        })
      else
        track_params
      end

    {:ok, track} =
      Track
      |> Ash.Changeset.for_create(:upsert, track_params, opts(tenant))
      |> Ash.create(opts(tenant))

    # Create track-artist joins
    artists = recording.artists || []

    artists
    |> Enum.with_index(1)
    |> Enum.each(fn {artist, seq} ->
      role = normalize_role(artist.role)
      # Artists are global
      db_artist = Catalog.upsert_artist!(%{name: artist.name}, actor: system_actor())

      TrackArtist
      |> Ash.Changeset.for_create(
        :upsert,
        %{track_id: track.id, artist_id: db_artist.id, role: role, sequence_number: seq},
        opts(tenant)
      )
      |> Ash.create!(opts(tenant))
    end)

    track
  end

  defp create_deals(deals, release, main_ref, tenant) do
    deals
    |> Enum.filter(fn d -> d.deal_release_reference == main_ref end)
    |> Enum.each(fn deal ->
      Deal
      |> Ash.Changeset.for_create(
        :upsert,
        %{
          release_id: release.id,
          commercial_model: deal.commercial_model,
          usage_types: deal.use_types || [],
          territory_codes: deal.territory_codes || [],
          start_date: deal.start_date,
          end_date: deal.end_date
        },
        opts(tenant)
      )
      |> Ash.create!(opts(tenant))
    end)
  end

  defp create_territory_releases(main_release, release, tenant) do
    dbt = main_release.details_by_territory

    if dbt && dbt.territory_code && dbt.territory_code != "" do
      TerritoryRelease
      |> Ash.Changeset.for_create(
        :upsert,
        %{
          release_id: release.id,
          territory_code: dbt.territory_code,
          title: dbt.title,
          display_artist: dbt.display_artist_name,
          label_name: dbt.label_name,
          genre: dbt.genre,
          sub_genre: dbt.sub_genre,
          language_code: dbt.language_code
        },
        opts(tenant)
      )
      |> Ash.create!(opts(tenant))
    end
  end

  defp normalize_release_type("Album"), do: :album
  defp normalize_release_type("Single"), do: :single
  defp normalize_release_type("EP"), do: :ep
  defp normalize_release_type("Compilation"), do: :compilation
  defp normalize_release_type(_), do: :other

  defp normalize_role("MainArtist"), do: :main
  defp normalize_role("FeaturedArtist"), do: :featured
  defp normalize_role("Remixer"), do: :remixer
  defp normalize_role("Composer"), do: :composer
  defp normalize_role("Producer"), do: :producer
  defp normalize_role(_), do: :main

  defp normalize_parental_warning("Explicit"), do: :explicit
  defp normalize_parental_warning("NotExplicit"), do: :not_explicit
  defp normalize_parental_warning(_), do: :unknown

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> nil
    end
  end
end
