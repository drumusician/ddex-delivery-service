defmodule DdexDeliveryService.Parser.Types.BooleanType do
  @behaviour DataSchema.CastBehaviour

  @impl true
  def cast(value) when is_binary(value) do
    case value do
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      "" -> {:ok, false}
      _ -> {:error, "Invalid boolean value: #{value}"}
    end
  end

  def cast(value) when is_integer(value) do
    case value do
      1 -> {:ok, true}
      0 -> {:ok, false}
      _ -> {:error, "Invalid boolean value: #{value}"}
    end
  end

  def cast(_), do: {:ok, false}
end
