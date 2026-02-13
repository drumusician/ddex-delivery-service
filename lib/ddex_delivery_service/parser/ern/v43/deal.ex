defmodule DdexDeliveryService.Parser.Ern.V43.Deal do
  import DataSchema, only: [data_schema: 1]

  alias DdexDeliveryService.Parser.XpathAccessor
  alias DdexDeliveryService.Parser.Types.{StringType, DateType}

  @data_accessor XpathAccessor
  data_schema(
    field: {:deal_release_reference, "./DealReleaseReference/text()", StringType},
    field:
      {:commercial_model, "./Deal[1]/DealTerms/CommercialModelType/text()", StringType,
       optional?: true, empty_values: [""]},
    list_of: {:use_types, "./Deal[1]/DealTerms/Usage/UseType/text()", StringType},
    list_of: {:territory_codes, "./Deal[1]/DealTerms/TerritoryCode/text()", StringType},
    field:
      {:start_date, "./Deal[1]/DealTerms/ValidityPeriod/StartDate/text()", DateType,
       optional?: true, empty_values: [""]},
    field:
      {:end_date, "./Deal[1]/DealTerms/ValidityPeriod/EndDate/text()", DateType,
       optional?: true, empty_values: [""]}
  )
end
