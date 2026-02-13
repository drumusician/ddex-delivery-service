defmodule DdexDeliveryService.FileStorageTest do
  use DdexDeliveryService.DataCase, async: true

  alias DdexDeliveryService.FileStorage
  alias DdexDeliveryService.Ingestion

  defp system_actor, do: %DdexDeliveryService.Accounts.SystemActor{}

  setup do
    org = create_test_org!()
    tenant = org.id

    {:ok, delivery} =
      Ingestion.create_delivery(
        %{source: :upload, status: :received, original_filename: "test.xml"},
        actor: system_actor(),
        tenant: tenant
      )

    %{org: org, tenant: tenant, delivery: delivery}
  end

  describe "generate_upload_url/4" do
    test "generates a presigned PUT URL", %{tenant: tenant, delivery: delivery} do
      {:ok, url, s3_key} =
        FileStorage.generate_upload_url(tenant, delivery.id, "test.xml",
          file_type: :xml,
          content_type: "application/xml"
        )

      assert is_binary(url)
      assert String.contains?(url, "ddex-deliveries")
      assert s3_key == "tenants/#{tenant}/deliveries/#{delivery.id}/xml/test.xml"
    end
  end

  describe "generate_download_url/2" do
    test "generates a presigned GET URL", %{tenant: tenant, delivery: delivery} do
      # Create a stored file record
      {:ok, stored_file} =
        Ingestion.create_stored_file(
          %{
            bucket: "ddex-deliveries",
            key: "tenants/#{tenant}/deliveries/#{delivery.id}/xml/test.xml",
            filename: "test.xml",
            content_type: "application/xml",
            byte_size: 1024,
            file_type: :xml,
            status: :stored,
            delivery_id: delivery.id
          },
          actor: system_actor(),
          tenant: tenant
        )

      {:ok, url} = FileStorage.generate_download_url(stored_file, ttl: 300)

      assert is_binary(url)
      assert String.contains?(url, "ddex-deliveries")
      assert String.contains?(url, stored_file.key)
    end
  end

  describe "register_file/3" do
    test "creates a StoredFile record", %{tenant: tenant, delivery: delivery} do
      {:ok, stored_file} =
        FileStorage.register_file(tenant, delivery.id, %{
          key: "tenants/#{tenant}/deliveries/#{delivery.id}/xml/test.xml",
          filename: "test.xml",
          content_type: "application/xml",
          byte_size: 2048,
          checksum_sha256: "abc123",
          file_type: :xml
        })

      assert stored_file.bucket == "ddex-deliveries"
      assert stored_file.filename == "test.xml"
      assert stored_file.status == :stored
      assert stored_file.delivery_id == delivery.id
      assert stored_file.byte_size == 2048
    end
  end

  describe "StoredFile resource" do
    test "stored files are tenant-scoped", %{tenant: tenant, delivery: delivery} do
      {:ok, _stored_file} =
        FileStorage.register_file(tenant, delivery.id, %{
          key: "tenants/#{tenant}/deliveries/#{delivery.id}/xml/test.xml",
          filename: "test.xml",
          content_type: "application/xml",
          byte_size: 1024,
          file_type: :xml
        })

      # Can list files within the same tenant
      files = Ingestion.list_stored_files!(actor: system_actor(), tenant: tenant)
      assert length(files) == 1

      # Different tenant sees no files
      other_org = create_test_org!("other-org")
      other_files = Ingestion.list_stored_files!(actor: system_actor(), tenant: other_org.id)
      assert other_files == []
    end

    test "can update file status to purged", %{tenant: tenant, delivery: delivery} do
      {:ok, stored_file} =
        FileStorage.register_file(tenant, delivery.id, %{
          key: "tenants/#{tenant}/deliveries/#{delivery.id}/audio/track.flac",
          filename: "track.flac",
          content_type: "audio/flac",
          byte_size: 50_000_000,
          file_type: :audio
        })

      assert stored_file.status == :stored

      {:ok, updated} =
        Ingestion.update_stored_file(
          stored_file,
          %{status: :purged, purged_at: DateTime.utc_now()},
          actor: system_actor(),
          tenant: tenant
        )

      assert updated.status == :purged
      assert updated.purged_at != nil
    end
  end
end
