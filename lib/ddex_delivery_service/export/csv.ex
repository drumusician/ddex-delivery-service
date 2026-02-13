defmodule DdexDeliveryService.Export.Csv do
  @moduledoc """
  CSV export for DDEX delivery data. Pure module — no web dependencies.
  Generates RFC 4180 compliant CSV output as iodata.
  """

  require Ash.Query

  alias DdexDeliveryService.Ingestion

  @track_headers [
    "release_title",
    "release_upc",
    "release_type",
    "release_date",
    "label_name",
    "release_display_artist",
    "release_p_line",
    "release_c_line",
    "track_number",
    "disc_number",
    "track_title",
    "isrc",
    "duration_seconds",
    "track_display_artist",
    "track_p_line",
    "track_c_line",
    "artists",
    "territory_codes",
    "commercial_model"
  ]

  @release_headers [
    "title",
    "upc",
    "release_type",
    "release_date",
    "original_release_date",
    "label_name",
    "display_artist",
    "catalog_number",
    "track_count",
    "duration_seconds",
    "p_line",
    "c_line",
    "parental_warning",
    "artists",
    "territory_codes",
    "deals"
  ]

  @doc """
  Export tracks for a delivery as a CSV binary.
  Returns `{:ok, csv_binary}` or `{:error, reason}`.
  """
  def export_tracks(delivery_id, org_id) do
    actor = %DdexDeliveryService.Accounts.SystemActor{}

    with {:ok, delivery} <-
           Ingestion.get_delivery_by_id(delivery_id, actor: actor, tenant: org_id),
         {:ok, releases} <- load_releases_with_tracks(delivery, actor, org_id) do
      rows =
        Enum.flat_map(releases, fn release ->
          tracks = release.tracks |> Enum.sort_by(&{&1.disc_number, &1.track_number})
          territory_codes = collect_territory_codes(release)
          commercial_model = primary_commercial_model(release)

          Enum.map(tracks, fn track ->
            [
              release.title,
              release.upc,
              format_atom(release.release_type),
              to_string(release.release_date || ""),
              label_name(release),
              release.display_artist,
              format_p_line(release.p_line),
              format_c_line(release.c_line),
              to_string(track.track_number || ""),
              to_string(track.disc_number || ""),
              track.title,
              track.isrc,
              to_string(track.duration || ""),
              track.display_artist,
              format_p_line(track.p_line),
              format_c_line(track.c_line),
              format_artists(track),
              Enum.join(territory_codes, "; "),
              commercial_model
            ]
          end)
        end)

      csv = encode_csv([@track_headers | rows])
      {:ok, csv}
    end
  end

  @doc """
  Export releases for a delivery as a CSV binary.
  Returns `{:ok, csv_binary}` or `{:error, reason}`.
  """
  def export_releases(delivery_id, org_id) do
    actor = %DdexDeliveryService.Accounts.SystemActor{}

    with {:ok, delivery} <-
           Ingestion.get_delivery_by_id(delivery_id, actor: actor, tenant: org_id),
         {:ok, releases} <- load_releases_with_tracks(delivery, actor, org_id) do
      rows =
        Enum.map(releases, fn release ->
          territory_codes = collect_territory_codes(release)
          deals_str = format_deals(release)

          [
            release.title,
            release.upc,
            format_atom(release.release_type),
            to_string(release.release_date || ""),
            to_string(release.original_release_date || ""),
            label_name(release),
            release.display_artist,
            release.catalog_number,
            to_string(length(loaded_list(release.tracks))),
            to_string(release.duration || ""),
            format_p_line(release.p_line),
            format_c_line(release.c_line),
            format_atom(release.parental_warning),
            format_artists(release),
            Enum.join(territory_codes, "; "),
            deals_str
          ]
        end)

      csv = encode_csv([@release_headers | rows])
      {:ok, csv}
    end
  end

  # --- Data loading ---

  defp load_releases_with_tracks(delivery, actor, org_id) do
    DdexDeliveryService.Catalog.Release
    |> Ash.Query.filter(delivery_id == ^delivery.id)
    |> Ash.Query.load([:artists, :label, :deals, :territory_releases, tracks: [:artists]])
    |> Ash.read(actor: actor, tenant: org_id)
  end

  # --- CSV encoding (RFC 4180) ---

  defp encode_csv(rows) do
    rows
    |> Enum.map(&encode_row/1)
    |> Enum.intersperse("\r\n")
    |> IO.iodata_to_binary()
    |> Kernel.<>("\r\n")
  end

  defp encode_row(fields) do
    fields
    |> Enum.map(&escape_field/1)
    |> Enum.intersperse(",")
  end

  defp escape_field(nil), do: ""

  defp escape_field(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n", "\r"]) do
      ["\"", String.replace(value, "\"", "\"\""), "\""]
    else
      value
    end
  end

  defp escape_field(value), do: escape_field(to_string(value))

  # --- Formatting helpers ---

  defp format_p_line(%{year: year, text: text}) when not is_nil(text) do
    if year, do: "(P) #{year} #{text}", else: "(P) #{text}"
  end

  defp format_p_line(_), do: ""

  defp format_c_line(%{year: year, text: text}) when not is_nil(text) do
    if year, do: "(C) #{year} #{text}", else: "(C) #{text}"
  end

  defp format_c_line(_), do: ""

  defp format_artists(%{artists: artists}) when is_list(artists) do
    artists
    |> Enum.map(& &1.name)
    |> Enum.join("; ")
  end

  defp format_artists(_), do: ""

  defp format_atom(nil), do: ""
  defp format_atom(atom) when is_atom(atom), do: to_string(atom)
  defp format_atom(other), do: to_string(other)

  defp label_name(%{label: %{name: name}}) when not is_nil(name), do: name
  defp label_name(_), do: ""

  defp collect_territory_codes(%{deals: deals}) when is_list(deals) do
    deals
    |> Enum.flat_map(& &1.territory_codes)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp collect_territory_codes(_), do: []

  defp primary_commercial_model(%{deals: [deal | _]}) when not is_nil(deal),
    do: deal.commercial_model || ""

  defp primary_commercial_model(_), do: ""

  defp format_deals(%{deals: deals}) when is_list(deals) do
    deals
    |> Enum.map(fn deal ->
      territories = Enum.join(deal.territory_codes, "/")
      "#{deal.commercial_model || ""}[#{territories}]"
    end)
    |> Enum.join("; ")
  end

  defp format_deals(_), do: ""

  defp loaded_list(%Ash.NotLoaded{}), do: []
  defp loaded_list(list) when is_list(list), do: list
  defp loaded_list(_), do: []
end
