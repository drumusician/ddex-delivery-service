defmodule DdexDeliveryService.Parser.Types.StringType do
  @behaviour DataSchema.CastBehaviour

  @impl true
  def cast(value) do
    {:ok, to_string(value)}
  end
end
