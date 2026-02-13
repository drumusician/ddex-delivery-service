defmodule DdexDeliveryService.SFTP.FileHandler do
  @moduledoc """
  Custom SFTP file handler that routes operations to per-org upload directories.

  Implements a wrapper around `:ssh_sftpd_file` (the default file handler) that:
  - Roots each connection to a per-org upload directory
  - Detects when a `BatchComplete*.xml` file is written and notifies the FileWatcher
  """

  require Logger

  @doc """
  Get the upload root directory for a given organization slug.
  """
  def upload_dir(org_slug) do
    root = upload_root()
    Path.join(root, org_slug)
  end

  @doc """
  Get the configured upload root path (absolute).
  """
  def upload_root do
    config = Application.get_env(:ddex_delivery_service, :sftp, [])
    root = Keyword.get(config, :upload_root, "priv/sftp/uploads")

    if Path.type(root) == :absolute do
      root
    else
      Application.app_dir(:ddex_delivery_service, root)
    end
  end

  @doc """
  Check if a filename matches the BatchComplete pattern and notify the file watcher.
  """
  def check_batch_complete(filepath) do
    filename = Path.basename(filepath)

    if batch_complete?(filename) do
      # Extract org_slug and batch dir from path
      # Path pattern: {upload_root}/{org_slug}/{batch_id}/BatchComplete_xxx.xml
      parts = Path.split(filepath)
      root_parts = Path.split(upload_root())
      relative = Enum.drop(parts, length(root_parts))

      case relative do
        [org_slug | _rest] ->
          batch_dir = Path.dirname(filepath)

          Logger.info(
            "BatchComplete detected: org=#{org_slug} batch_dir=#{batch_dir}"
          )

          DdexDeliveryService.SFTP.FileWatcher.batch_complete(org_slug, batch_dir)

        _ ->
          Logger.warning("BatchComplete file detected but could not determine org: #{filepath}")
      end
    end
  end

  @doc """
  Check if a filename matches the BatchComplete pattern.
  """
  def batch_complete?(filename) do
    String.starts_with?(filename, "BatchComplete") and String.ends_with?(filename, ".xml")
  end

  @doc """
  Ensure the upload directory exists for an org.
  """
  def ensure_upload_dir(org_slug) do
    dir = upload_dir(org_slug)
    File.mkdir_p!(dir)
    dir
  end
end
