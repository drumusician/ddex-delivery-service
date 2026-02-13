defmodule DdexDeliveryService.Parser.Ern.V43.SoundRecording do
  import DataSchema, only: [data_schema: 1]

  alias DdexDeliveryService.Parser.XpathAccessor
  alias DdexDeliveryService.Parser.Types.{StringType, DurationType, IntegerType}
  alias DdexDeliveryService.Parser.Ern.V43.DisplayArtist

  @data_accessor XpathAccessor
  data_schema(
    field: {:isrc, "./SoundRecordingId/ISRC/text()", StringType, optional?: true, empty_values: [""]},
    field: {:resource_reference, "./ResourceReference/text()", StringType},
    field: {:title, "./ReferenceTitle/TitleText/text()", StringType},
    field: {:duration, "./Duration/text()", DurationType, optional?: true, empty_values: [""]},
    field:
      {:display_artist_name,
       "./SoundRecordingDetailsByTerritory/DisplayArtistName/text()", StringType,
       optional?: true, empty_values: [""]},
    has_many:
      {:artists, "./SoundRecordingDetailsByTerritory/DisplayArtist", DisplayArtist},
    field:
      {:label_name, "./SoundRecordingDetailsByTerritory/LabelName/text()", StringType,
       optional?: true, empty_values: [""]},
    field:
      {:p_line_year, "./SoundRecordingDetailsByTerritory/PLine/Year/text()", IntegerType,
       optional?: true, empty_values: [""]},
    field:
      {:p_line_text, "./SoundRecordingDetailsByTerritory/PLine/PLineText/text()", StringType,
       optional?: true, empty_values: [""]},
    field:
      {:genre, "./SoundRecordingDetailsByTerritory/Genre/GenreText/text()", StringType,
       optional?: true, empty_values: [""]},
    field:
      {:sub_genre, "./SoundRecordingDetailsByTerritory/Genre/SubGenre/text()", StringType,
       optional?: true, empty_values: [""]},
    field:
      {:territory_code, "./SoundRecordingDetailsByTerritory/TerritoryCode/text()", StringType,
       optional?: true, empty_values: [""]}
  )
end
