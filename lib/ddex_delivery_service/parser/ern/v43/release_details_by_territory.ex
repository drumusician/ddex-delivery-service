defmodule DdexDeliveryService.Parser.Ern.V43.ReleaseDetailsByTerritory do
  import DataSchema, only: [data_schema: 1]

  alias DdexDeliveryService.Parser.XpathAccessor
  alias DdexDeliveryService.Parser.Types.StringType
  alias DdexDeliveryService.Parser.Ern.V43.DisplayArtist

  @data_accessor XpathAccessor
  data_schema(
    field: {:territory_code, "./TerritoryCode/text()", StringType, optional?: true, empty_values: [""]},
    field: {:display_artist_name, "./DisplayArtistName/text()", StringType, optional?: true, empty_values: [""]},
    has_many: {:artists, "./DisplayArtist", DisplayArtist},
    field: {:label_name, "./LabelName/text()", StringType, optional?: true, empty_values: [""]},
    field: {:title, "./Title/TitleText/text()", StringType, optional?: true, empty_values: [""]},
    field: {:genre, "./Genre/GenreText/text()", StringType, optional?: true, empty_values: [""]},
    field: {:sub_genre, "./Genre/SubGenre/text()", StringType, optional?: true, empty_values: [""]},
    field: {:parental_warning, "./ParentalWarningType/text()", StringType, optional?: true, empty_values: [""]},
    field: {:language_code, "./LanguageAndScriptCode/text()", StringType, optional?: true, empty_values: [""]}
  )
end
