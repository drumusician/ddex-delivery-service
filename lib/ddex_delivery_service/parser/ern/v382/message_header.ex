defmodule DdexDeliveryService.Parser.Ern.V382.MessageHeader do
  import DataSchema, only: [data_schema: 1]

  alias DdexDeliveryService.Parser.XpathAccessor
  alias DdexDeliveryService.Parser.Types.StringType

  @data_accessor XpathAccessor
  data_schema(
    field: {:message_id, "./MessageId/text()", StringType},
    field: {:message_thread_id, "./MessageThreadId/text()", StringType},
    field:
      {:sender_name, "./MessageSender/PartyName/FullName/text()", StringType,
       optional?: true, empty_values: [""]},
    field:
      {:sender_party_id, "./MessageSender/PartyId/text()", StringType,
       optional?: true, empty_values: [""]},
    field:
      {:recipient_name, "./MessageRecipient/PartyName/FullName/text()", StringType,
       optional?: true, empty_values: [""]},
    field: {:created_at, "./MessageCreatedDateTime/text()", StringType}
  )
end
