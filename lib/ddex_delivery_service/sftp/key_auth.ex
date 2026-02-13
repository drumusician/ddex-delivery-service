defmodule DdexDeliveryService.SFTP.KeyAuth do
  @moduledoc """
  SSH public key authentication for the SFTP server.

  Matches incoming SSH public keys against stored SftpKey records in the database.
  Returns the organization associated with the matching key.
  """

  require Logger

  defp system_actor, do: %DdexDeliveryService.Accounts.SystemActor{}

  @doc """
  Callback for `:ssh.daemon/2` `publickey_auth_fun` option.

  Returns `true` if the key matches an active SftpKey record.
  The username is expected to be the org slug.
  """
  def authenticate(username, public_key) do
    fingerprint = compute_fingerprint(public_key)

    case find_key_by_fingerprint(fingerprint) do
      {:ok, sftp_key} ->
        Logger.info("SFTP auth success: user=#{username} fingerprint=#{fingerprint} org=#{sftp_key.organization_id}")
        true

      :not_found ->
        Logger.warning("SFTP auth failed: user=#{username} fingerprint=#{fingerprint}")
        false
    end
  end

  @doc """
  Look up an organization ID by SSH public key fingerprint.
  """
  def org_for_fingerprint(fingerprint) do
    case find_key_by_fingerprint(fingerprint) do
      {:ok, sftp_key} -> {:ok, sftp_key.organization_id}
      :not_found -> :error
    end
  end

  @doc """
  Look up an organization by SSH public key (Erlang tuple format).
  """
  def org_for_public_key(public_key) do
    fingerprint = compute_fingerprint(public_key)
    org_for_fingerprint(fingerprint)
  end

  @doc """
  Compute the SHA256 fingerprint of an SSH public key.

  Accepts either an Erlang public key tuple or raw binary.
  Returns a hex-encoded SHA256 hash string.
  """
  def compute_fingerprint(public_key) when is_binary(public_key) do
    :crypto.hash(:sha256, public_key) |> Base.encode16(case: :lower)
  end

  def compute_fingerprint(public_key) do
    # Encode the public key to its SSH wire format for fingerprinting
    encoded = :erlang.term_to_binary(public_key)
    :crypto.hash(:sha256, encoded) |> Base.encode16(case: :lower)
  end

  @doc """
  Compute fingerprint from an authorized_keys format string (e.g., "ssh-rsa AAAA... label").
  """
  def compute_fingerprint_from_authorized_keys(key_string) when is_binary(key_string) do
    # Parse "ssh-rsa AAAAB3... comment" format
    parts = String.split(key_string, " ", parts: 3)

    case parts do
      [_type, base64_key | _] ->
        raw = Base.decode64!(base64_key)
        :crypto.hash(:sha256, raw) |> Base.encode16(case: :lower)

      _ ->
        # Try as raw base64
        raw = Base.decode64!(String.trim(key_string))
        :crypto.hash(:sha256, raw) |> Base.encode16(case: :lower)
    end
  end

  defp find_key_by_fingerprint(fingerprint) do
    case DdexDeliveryService.Accounts.get_sftp_key_by_fingerprint(fingerprint, actor: system_actor()) do
      {:ok, [sftp_key | _]} -> {:ok, sftp_key}
      {:ok, []} -> :not_found
      _ -> :not_found
    end
  end
end
