defmodule DdexDeliveryService.Parser.Types.IntegerType do
  @behaviour DataSchema.CastBehaviour

  @impl true
  def cast(""), do: {:ok, nil}

  def cast(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      {int, _} -> {:ok, int}
      :error -> {:error, "Invalid integer value: #{value}"}
    end
  end

  def cast(value) when is_integer(value), do: {:ok, value}
  def cast(_), do: {:ok, nil}
end
