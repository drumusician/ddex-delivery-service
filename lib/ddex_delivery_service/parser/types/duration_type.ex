defmodule DdexDeliveryService.Parser.Types.DurationType do
  @moduledoc """
  Parses ISO 8601 duration strings (e.g. PT3M45S, PT1H2M30S) into seconds.
  """
  @behaviour DataSchema.CastBehaviour

  @impl true
  def cast(""), do: {:ok, nil}

  def cast(value) when is_binary(value) do
    case parse_duration(value) do
      {:ok, seconds} -> {:ok, seconds}
      :error -> {:error, "Invalid duration value: #{value}"}
    end
  end

  def cast(_), do: {:ok, nil}

  defp parse_duration(<<"PT", rest::binary>>) do
    parse_time_components(rest, 0)
  end

  defp parse_duration(<<"P", rest::binary>>) do
    # Skip date parts (days/months/years) and look for T
    case String.split(rest, "T", parts: 2) do
      [_date_part, time_part] -> parse_time_components(time_part, 0)
      [_date_only] -> {:ok, 0}
    end
  end

  defp parse_duration(_), do: :error

  defp parse_time_components("", seconds), do: {:ok, seconds}

  defp parse_time_components(str, seconds) do
    case Regex.run(~r/^(\d+(?:\.\d+)?)([HMS])(.*)$/, str) do
      [_, num_str, unit, rest] ->
        num = parse_number(num_str)

        added =
          case unit do
            "H" -> num * 3600
            "M" -> num * 60
            "S" -> num
          end

        parse_time_components(rest, seconds + trunc(added))

      _ ->
        :error
    end
  end

  defp parse_number(str) do
    case Float.parse(str) do
      {num, ""} -> num
      _ -> 0
    end
  end
end
