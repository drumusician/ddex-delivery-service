defmodule DdexDeliveryService.ParserTest do
  use ExUnit.Case, async: true

  alias DdexDeliveryService.Parser
  alias DdexDeliveryService.Parser.Validators.IdentifierValidator

  @fixtures_path "priv/ddex/fixtures"

  describe "detect_version/1" do
    test "detects ERN 3.8.2 from MessageSchemaVersionId" do
      xml = ~s(<?xml version="1.0"?><ern:NewReleaseMessage xmlns:ern="http://ddex.net/xml/ern/382" MessageSchemaVersionId="ern/382"><MessageHeader/></ern:NewReleaseMessage>)
      assert {:ok, "3.8.2"} = Parser.detect_version(xml)
    end

    test "detects ERN 4.3 from MessageSchemaVersionId" do
      xml = ~s(<?xml version="1.0"?><NewReleaseMessage xmlns="http://ddex.net/xml/ern/43" MessageSchemaVersionId="ern/43"><MessageHeader/></NewReleaseMessage>)
      assert {:ok, "4.3"} = Parser.detect_version(xml)
    end

    test "detects ERN 3.8.x from namespace URI" do
      xml = ~s(<?xml version="1.0"?><ern:NewReleaseMessage xmlns:ern="http://ddex.net/xml/ern/38"><MessageHeader/></ern:NewReleaseMessage>)
      assert {:ok, "3.8.2"} = Parser.detect_version(xml)
    end

    test "detects ERN 3.8.1 from namespace URI" do
      xml = ~s(<?xml version="1.0"?><ern:NewReleaseMessage xmlns:ern="http://ddex.net/xml/ern/381" MessageSchemaVersionId="ern/381"><MessageHeader/></ern:NewReleaseMessage>)
      assert {:ok, "3.8.2"} = Parser.detect_version(xml)
    end

    test "returns error for unknown version" do
      xml = ~s(<?xml version="1.0"?><SomeOtherMessage/>)
      assert {:error, :unknown_version} = Parser.detect_version(xml)
    end
  end

  describe "parse/1 with ERN 3.8.2 fixture" do
    setup do
      xml = File.read!(Path.join(@fixtures_path, "sample_album_ern382.xml"))
      {:ok, message} = Parser.parse(xml)
      %{message: message}
    end

    test "detects version", %{message: message} do
      assert message.version == "ern/382"
    end

    test "parses message header", %{message: message} do
      assert message.message_header.message_id == "MSG-2024-001-001"
      assert message.message_header.sender_name == "Demo Music Distribution"
    end

    test "parses sound recordings", %{message: message} do
      assert length(message.sound_recordings) == 10

      first = hd(message.sound_recordings)
      assert first.isrc == "NLA401234501"
      assert first.title == "Midnight Signal"
      assert first.resource_reference == "A1"
      assert first.duration == 252
      assert first.display_artist_name == "Aurora Waves"
      assert first.genre == "Electronic"
    end

    test "parses sound recording artists", %{message: message} do
      # Track 5 has a featured artist
      track5 = Enum.at(message.sound_recordings, 4)
      assert length(track5.artists) == 2
      assert hd(track5.artists).name == "Aurora Waves"
      assert hd(track5.artists).role == "MainArtist"
      assert Enum.at(track5.artists, 1).name == "Echo Module"
      assert Enum.at(track5.artists, 1).role == "FeaturedArtist"
    end

    test "parses releases", %{message: message} do
      assert length(message.releases) == 11

      main = hd(message.releases)
      assert main.is_main_release == true
      assert main.icpn == "5400123456789"
      assert main.title == "Signals from the Deep"
      assert main.release_type == "Album"
      assert main.release_date == ~D[2024-09-15]
      assert main.duration == 2848
      assert main.p_line_text == "2024 Neon Harbor Records"
      assert main.c_line_text == "2024 Neon Harbor Records"
      assert length(main.resource_references) == 11
    end

    test "parses release details by territory", %{message: message} do
      main = hd(message.releases)
      dbt = main.details_by_territory

      assert dbt.territory_code == "Worldwide"
      assert dbt.display_artist_name == "Aurora Waves"
      assert dbt.label_name == "Neon Harbor Records"
      assert dbt.title == "Signals from the Deep"
      assert dbt.genre == "Electronic"
      assert dbt.sub_genre == "Synthwave"
      assert dbt.parental_warning == "NotExplicit"
    end

    test "parses track releases", %{message: message} do
      track_releases = Enum.filter(message.releases, &(&1.release_type == "TrackRelease"))
      assert length(track_releases) == 10

      first_track = hd(track_releases)
      assert first_track.isrc == "NLA401234501"
      assert first_track.title == "Midnight Signal"
    end

    test "parses deals", %{message: message} do
      assert length(message.deals) == 1

      deal = hd(message.deals)
      assert deal.deal_release_reference == "R0"
      assert deal.commercial_model == "PayAsYouGoModel"
      assert "OnDemandStream" in deal.use_types
      assert "PermanentDownload" in deal.use_types
      assert "Worldwide" in deal.territory_codes
      assert deal.start_date == ~D[2024-09-15]
    end

    test "parses images", %{message: message} do
      assert length(message.images) == 1
      assert hd(message.images).image_type == "FrontCoverImage"
      assert hd(message.images).resource_reference == "A11"
    end
  end

  describe "parse/1 with ERN 4.3 fixture" do
    setup do
      xml = File.read!(Path.join(@fixtures_path, "sample_single_ern43.xml"))
      {:ok, message} = Parser.parse(xml)
      %{message: message}
    end

    test "detects version", %{message: message} do
      assert message.version == "ern/43"
    end

    test "parses message header", %{message: message} do
      assert message.message_header.message_id == "MSG-2025-042-001"
      assert message.message_header.sender_name == "Stellar Distribution Co"
    end

    test "parses parties (ERN 4.3 specific)", %{message: message} do
      assert length(message.parties) == 3

      luma = Enum.find(message.parties, &(&1.name == "Luma Vasquez"))
      assert luma.isni == "0000000512345678"

      kael = Enum.find(message.parties, &(&1.name == "Kael Torres"))
      assert kael.ddex_party_id == "PADPIDA2025030301Z"
    end

    test "parses sound recordings", %{message: message} do
      assert length(message.sound_recordings) == 2

      first = hd(message.sound_recordings)
      assert first.isrc == "USA402500101"
      assert first.title == "Tangerine Skies"
      assert first.duration == 202
    end

    test "parses main release", %{message: message} do
      main = Enum.find(message.releases, & &1.is_main_release)
      assert main.icpn == "0196118275463"
      assert main.title == "Tangerine Skies"
      assert main.release_type == "Single"
      assert main.release_date == ~D[2025-03-14]
    end

    test "parses deals", %{message: message} do
      assert length(message.deals) == 1
      deal = hd(message.deals)
      assert deal.commercial_model == "SubscriptionModel"
      assert "OnDemandStream" in deal.use_types
    end
  end

  describe "DurationType" do
    alias DdexDeliveryService.Parser.Types.DurationType

    test "parses minutes and seconds" do
      assert {:ok, 225} = DurationType.cast("PT3M45S")
    end

    test "parses hours, minutes, seconds" do
      assert {:ok, 3750} = DurationType.cast("PT1H2M30S")
    end

    test "parses seconds only" do
      assert {:ok, 45} = DurationType.cast("PT45S")
    end

    test "parses minutes only" do
      assert {:ok, 180} = DurationType.cast("PT3M")
    end

    test "returns nil for empty string" do
      assert {:ok, nil} = DurationType.cast("")
    end

    test "returns error for invalid format" do
      assert {:error, _} = DurationType.cast("invalid")
    end
  end

  describe "DateType" do
    alias DdexDeliveryService.Parser.Types.DateType

    test "parses normal ISO date" do
      assert {:ok, ~D[2025-03-14]} = DateType.cast("2025-03-14")
    end

    test "handles concatenated dates from XPath text() joining" do
      # SweetXml's text() with `s` modifier concatenates all matching text nodes
      assert {:ok, ~D[2008-01-01]} = DateType.cast("2008-01-012008-01-012008-01-01")
    end

    test "returns nil for empty string" do
      assert {:ok, nil} = DateType.cast("")
    end

    test "returns error for invalid format" do
      assert {:error, _} = DateType.cast("not-a-date")
    end
  end

  describe "IdentifierValidator" do
    test "validates correct ISRCs" do
      assert IdentifierValidator.valid_isrc?("NLA401234501")
      assert IdentifierValidator.valid_isrc?("USRC11234567")
      assert IdentifierValidator.valid_isrc?("GB-AYM-12-34567")
    end

    test "rejects invalid ISRCs" do
      refute IdentifierValidator.valid_isrc?("")
      refute IdentifierValidator.valid_isrc?(nil)
      refute IdentifierValidator.valid_isrc?("TOOSHORT")
      refute IdentifierValidator.valid_isrc?("123456789012")
    end

    test "validates correct UPCs" do
      assert IdentifierValidator.valid_upc?("5400123456789")
      assert IdentifierValidator.valid_upc?("012345678901")
    end

    test "rejects invalid UPCs" do
      refute IdentifierValidator.valid_upc?("")
      refute IdentifierValidator.valid_upc?(nil)
      refute IdentifierValidator.valid_upc?("12345")
      refute IdentifierValidator.valid_upc?("ABCDEFGHIJKLM")
    end
  end
end
