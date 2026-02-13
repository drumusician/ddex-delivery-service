defmodule DdexDeliveryService.Parser.Ern.V382.DisplayArtist do
  import DataSchema, only: [data_schema: 1]

  alias DdexDeliveryService.Parser.XpathAccessor
  alias DdexDeliveryService.Parser.Types.StringType

  @data_accessor XpathAccessor
  data_schema(
    field: {:name, "./PartyName/FullName/text()", StringType},
    field: {:role, "./ArtistRole/text()", StringType, optional?: true, empty_values: [""]}
  )
end
