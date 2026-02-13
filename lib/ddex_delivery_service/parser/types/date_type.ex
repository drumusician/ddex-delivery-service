defmodule DdexDeliveryService.Parser.Types.DateType do
  @behaviour DataSchema.CastBehaviour

  @impl true
  def cast(""), do: {:ok, nil}

  def cast(value) when is_binary(value) do
    # SweetXml's text() with the `s` modifier concatenates all matching text
    # nodes into one string. When multiple Deal elements each have a StartDate,
    # we get e.g. "2008-01-012008-01-012008-01-01". Take only the first 10
    # characters (ISO 8601 date length: YYYY-MM-DD) to handle this gracefully.
    date_str = String.slice(value, 0, 10)

    case Date.from_iso8601(date_str) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, "Invalid date value: #{value}"}
    end
  end

  def cast(_), do: {:ok, nil}
end
