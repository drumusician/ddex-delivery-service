defmodule DdexDeliveryService.Parser.Ern.V43.Party do
  import DataSchema, only: [data_schema: 1]

  alias DdexDeliveryService.Parser.XpathAccessor
  alias DdexDeliveryService.Parser.Types.StringType

  @data_accessor XpathAccessor
  data_schema(
    field: {:party_reference, "./PartyReference/text()", StringType},
    field: {:name, "./PartyName/FullName/text()", StringType},
    field: {:isni, "./PartyId/ISNI/text()", StringType, optional?: true, empty_values: [""]},
    field: {:ddex_party_id, "./PartyId/DPID/text()", StringType, optional?: true, empty_values: [""]}
  )
end
