defmodule DdexDeliveryService.Parser.Ern.V382.Image do
  import DataSchema, only: [data_schema: 1]

  alias DdexDeliveryService.Parser.XpathAccessor
  alias DdexDeliveryService.Parser.Types.StringType

  @data_accessor XpathAccessor
  data_schema(
    field: {:image_type, "./ImageType/text()", StringType, optional?: true, empty_values: [""]},
    field: {:resource_reference, "./ResourceReference/text()", StringType}
  )
end
