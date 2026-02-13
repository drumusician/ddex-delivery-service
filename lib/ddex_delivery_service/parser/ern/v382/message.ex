defmodule DdexDeliveryService.Parser.Ern.V382.Message do
  import DataSchema, only: [data_schema: 1]

  alias DdexDeliveryService.Parser.XpathAccessor
  alias DdexDeliveryService.Parser.Types.StringType
  alias DdexDeliveryService.Parser.Ern.V382.{MessageHeader, Release, SoundRecording, Image, Deal}

  @data_accessor XpathAccessor
  data_schema(
    field:
      {:version, "//*[local-name()='NewReleaseMessage']/@MessageSchemaVersionId", StringType,
       optional?: true, empty_values: [""]},
    has_one: {:message_header, "//MessageHeader", MessageHeader},
    has_many: {:sound_recordings, "//ResourceList/SoundRecording", SoundRecording},
    has_many: {:images, "//ResourceList/Image", Image},
    has_many: {:releases, "//ReleaseList/Release", Release},
    has_many: {:deals, "//DealList/ReleaseDeal", Deal}
  )
end
