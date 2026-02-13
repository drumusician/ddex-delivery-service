defmodule DdexDeliveryService.Parser do
  @moduledoc """
  Public API for parsing DDEX ERN messages.

  Supports ERN 3.8.2 and 4.3 formats. Auto-detects version from XML
  namespace/attribute or accepts an explicit version string.
  """

  import SweetXml, only: [sigil_x: 2]

  alias DdexDeliveryService.Parser.Ern.V382
  alias DdexDeliveryService.Parser.Ern.V43

  @doc """
  Parse a DDEX ERN XML string. Auto-detects version.

  Returns `{:ok, parsed_message}` or `{:error, reason}`.
  """
  def parse(xml_string) do
    case detect_version(xml_string) do
      {:ok, version} -> parse(xml_string, version)
      {:error, _} = error -> error
    end
  end

  @doc """
  Parse a DDEX ERN XML string with an explicit version.
  """
  def parse(xml_string, version) when version in ["3.8.2", "3.8.1", "3.8", "ern/382", "ern/381", "ern/38"] do
    case DataSchema.to_struct(xml_string, V382.Message) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, {:parse_error, reason}}
    end
  end

  def parse(xml_string, version) when version in ["4.3", "4.2", "4.1", "ern/43", "ern/42", "ern/41"] do
    case DataSchema.to_struct(xml_string, V43.Message) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, {:parse_error, reason}}
    end
  end

  def parse(_xml_string, version) do
    {:error, {:unsupported_version, version}}
  end

  @doc """
  Detect the ERN version from the XML.

  Looks at the MessageSchemaVersionId attribute on the root element,
  as well as the XML namespace.

  Returns `{:ok, "3.8.2"}`, `{:ok, "4.3"}`, or `{:error, :unknown_version}`.
  """
  def detect_version(xml_string) do
    version_id =
      SweetXml.xpath(
        xml_string,
        ~x"//*[local-name()='NewReleaseMessage']/@MessageSchemaVersionId"s
      )

    detect_from_version_id(version_id) ||
      detect_from_namespace(xml_string) ||
      {:error, :unknown_version}
  end

  # Match explicit version ID attribute values like "ern/382", "ern/43", etc.
  # Also handles less common formats like "ern/38", "ern/381", "/382", etc.
  defp detect_from_version_id(""), do: nil

  defp detect_from_version_id(version_id) do
    cond do
      # ERN 4.x family
      Regex.match?(~r/4[._]?3/, version_id) -> {:ok, "4.3"}
      Regex.match?(~r/4[._]?[12]/, version_id) -> {:ok, "4.3"}
      # ERN 3.8.x family — treat all 3.8.x as 3.8.2 (our parser handles the family)
      Regex.match?(~r/3[._]?8/, version_id) -> {:ok, "3.8.2"}
      true -> nil
    end
  end

  # Fall back to checking namespace URIs and other strings in the XML
  defp detect_from_namespace(xml_string) do
    cond do
      # Standard namespace patterns
      String.contains?(xml_string, "ern/382") -> {:ok, "3.8.2"}
      String.contains?(xml_string, "ern/381") -> {:ok, "3.8.2"}
      String.contains?(xml_string, "ern/38") -> {:ok, "3.8.2"}
      String.contains?(xml_string, "ern/43") -> {:ok, "4.3"}
      String.contains?(xml_string, "ern/42") -> {:ok, "4.3"}
      String.contains?(xml_string, "ern/41") -> {:ok, "4.3"}
      # Colon-separated patterns (less common)
      String.contains?(xml_string, "ern:382") -> {:ok, "3.8.2"}
      String.contains?(xml_string, "ern:38") -> {:ok, "3.8.2"}
      String.contains?(xml_string, "ern:43") -> {:ok, "4.3"}
      # Broader namespace checks for DDEX ERN schemas
      Regex.match?(~r/ddex\.net\/xml\/ern\/3/, xml_string) -> {:ok, "3.8.2"}
      Regex.match?(~r/ddex\.net\/xml\/ern\/4/, xml_string) -> {:ok, "4.3"}
      true -> nil
    end
  end

  @doc """
  Parse a DDEX ERN XML file from disk.
  """
  def parse_file(path) do
    path
    |> File.read!()
    |> parse()
  end

  @doc """
  Parse a DDEX ERN XML file from disk with an explicit version.
  """
  def parse_file(path, version) do
    path
    |> File.read!()
    |> parse(version)
  end
end
