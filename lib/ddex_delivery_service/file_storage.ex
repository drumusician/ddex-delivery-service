defmodule DdexDeliveryService.FileStorage do
  @moduledoc """
  Handles file storage operations via S3-compatible storage (Tigris/AWS S3).

  This is the only module that talks to S3. All file operations go through here.

  Key pattern: `tenants/{org_id}/deliveries/{delivery_id}/{type}/{filename}`
  """

  alias DdexDeliveryService.Ingestion

  defp system_actor, do: %DdexDeliveryService.Accounts.SystemActor{}

  defp bucket do
    Application.get_env(:ddex_delivery_service, :storage_bucket, "ddex-deliveries")
  end

  defp s3_config do
    config = Application.get_env(:ddex_delivery_service, :ex_aws, [])

    if config[:host] do
      [host: config[:host], scheme: config[:scheme] || "https://", port: config[:port] || 443]
    else
      []
    end
  end

  @doc """
  Generate a presigned URL for uploading a file.

  Returns `{:ok, upload_url, s3_key}` or `{:error, reason}`.

  The URL is valid for `ttl_seconds` (default: 3600 = 1 hour).
  """
  def generate_upload_url(org_id, delivery_id, filename, opts \\ []) do
    file_type = Keyword.get(opts, :file_type, :xml)
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")
    ttl_seconds = Keyword.get(opts, :ttl, 3600)

    s3_key = build_key(org_id, delivery_id, file_type, filename)

    {:ok, url} =
      ExAws.S3.presigned_url(
        ExAws.Config.new(:s3, s3_config()),
        :put,
        bucket(),
        s3_key,
        expires_in: ttl_seconds,
        query_params: [{"Content-Type", content_type}]
      )

    {:ok, url, s3_key}
  end

  @doc """
  Generate a presigned URL for downloading a file.

  Returns `{:ok, download_url}` or `{:error, reason}`.

  The URL is valid for `ttl_seconds` (default: 300 = 5 minutes).
  """
  def generate_download_url(stored_file, opts \\ []) do
    ttl_seconds = Keyword.get(opts, :ttl, 300)

    {:ok, url} =
      ExAws.S3.presigned_url(
        ExAws.Config.new(:s3, s3_config()),
        :get,
        stored_file.bucket,
        stored_file.key,
        expires_in: ttl_seconds
      )

    {:ok, url}
  end

  @doc """
  Store a file record in the database after a successful upload.

  Creates a StoredFile resource linked to the delivery.
  """
  def register_file(org_id, delivery_id, attrs) do
    params =
      Map.merge(attrs, %{
        bucket: bucket(),
        delivery_id: delivery_id,
        status: :stored
      })

    Ingestion.create_stored_file(params, actor: system_actor(), tenant: org_id)
  end

  @doc """
  Store XML content directly to S3 and create a StoredFile record.

  Used by the ingestion pipeline to store the original DDEX XML.
  """
  def store_xml(xml_content, org_id, delivery_id, filename) do
    s3_key = build_key(org_id, delivery_id, :xml, filename)
    byte_size = byte_size(xml_content)
    checksum = :crypto.hash(:sha256, xml_content) |> Base.encode16(case: :lower)

    case upload_to_s3(s3_key, xml_content, "application/xml") do
      {:ok, _} ->
        register_file(org_id, delivery_id, %{
          key: s3_key,
          filename: filename,
          content_type: "application/xml",
          byte_size: byte_size,
          checksum_sha256: checksum,
          file_type: :xml
        })

      {:error, reason} ->
        {:error, {:upload_failed, reason}}
    end
  end

  @doc """
  Delete a single file from S3.
  """
  def delete_file(stored_file) do
    case ExAws.S3.delete_object(stored_file.bucket, stored_file.key)
         |> ExAws.request(s3_config()) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Delete all files for a delivery from S3 and mark them as purged.
  """
  def delete_delivery_files(delivery_id, org_id) do
    stored_files =
      Ingestion.list_stored_files!(
        query: [filter: [delivery_id: delivery_id, status: :stored]],
        actor: system_actor(),
        tenant: org_id
      )

    Enum.each(stored_files, fn file ->
      case delete_file(file) do
        :ok ->
          Ingestion.update_stored_file(file,
            %{status: :purged, purged_at: DateTime.utc_now()},
            actor: system_actor(),
            tenant: org_id
          )

        {:error, _reason} ->
          :ok
      end
    end)

    :ok
  end

  defp build_key(org_id, delivery_id, file_type, filename) do
    "tenants/#{org_id}/deliveries/#{delivery_id}/#{file_type}/#{filename}"
  end

  defp upload_to_s3(s3_key, content, content_type) do
    ExAws.S3.put_object(bucket(), s3_key, content, content_type: content_type)
    |> ExAws.request(s3_config())
  end
end
