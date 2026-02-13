defmodule DdexDeliveryService.Parser.Ern.V382.Release do
  import DataSchema, only: [data_schema: 1]

  alias DdexDeliveryService.Parser.XpathAccessor
  alias DdexDeliveryService.Parser.Types.{StringType, BooleanType, DateType, DurationType}
  alias DdexDeliveryService.Parser.Ern.V382.ReleaseDetailsByTerritory

  @data_accessor XpathAccessor
  data_schema(
    field: {:icpn, "./ReleaseId/ICPN/text()", StringType, optional?: true, empty_values: [""]},
    field: {:isrc, "./ReleaseId/ISRC/text()", StringType, optional?: true, empty_values: [""]},
    field: {:release_reference, "./ReleaseReference/text()", StringType},
    field: {:title, "./ReferenceTitle/TitleText/text()", StringType},
    field: {:release_type, "./ReleaseType/text()", StringType},
    field: {:is_main_release, "./@IsMainRelease", BooleanType},
    field: {:release_date, "./ReleaseDate/text()", DateType, optional?: true, empty_values: [""]},
    field: {:duration, "./Duration/text()", DurationType, optional?: true, empty_values: [""]},
    field: {:p_line_year, "./PLine/Year/text()", StringType, optional?: true, empty_values: [""]},
    field: {:p_line_text, "./PLine/PLineText/text()", StringType, optional?: true, empty_values: [""]},
    field: {:c_line_year, "./CLine/Year/text()", StringType, optional?: true, empty_values: [""]},
    field: {:c_line_text, "./CLine/CLineText/text()", StringType, optional?: true, empty_values: [""]},
    list_of:
      {:resource_references, "./ReleaseResourceReferenceList/ReleaseResourceReference/text()",
       StringType},
    has_one: {:details_by_territory, "./ReleaseDetailsByTerritory", ReleaseDetailsByTerritory}
  )
end
