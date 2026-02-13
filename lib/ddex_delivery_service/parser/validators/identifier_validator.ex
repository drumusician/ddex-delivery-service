defmodule DdexDeliveryService.Parser.Validators.IdentifierValidator do
  @moduledoc """
  Validates DDEX identifiers like ISRC and UPC/EAN codes.
  """

  @isrc_regex ~r/^[A-Z]{2}[A-Z0-9]{3}\d{7}$/
  @upc_regex ~r/^\d{12,14}$/

  @doc """
  Validates an ISRC (International Standard Recording Code).
  Format: CC-XXX-YY-NNNNN (stored without hyphens: CCXXXYYNNNNN)
  """
  def valid_isrc?(nil), do: false
  def valid_isrc?(""), do: false

  def valid_isrc?(isrc) when is_binary(isrc) do
    clean = String.replace(isrc, "-", "")
    Regex.match?(@isrc_regex, clean)
  end

  @doc """
  Validates a UPC/EAN (Universal Product Code / European Article Number).
  12-14 digits.
  """
  def valid_upc?(nil), do: false
  def valid_upc?(""), do: false

  def valid_upc?(upc) when is_binary(upc) do
    Regex.match?(@upc_regex, upc)
  end
end
