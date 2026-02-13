defmodule DdexDeliveryService.SFTP.SSHKeyCallback do
  @moduledoc """
  SSH key callback module for the SFTP server.

  Implements the `:ssh_server_key_api` behaviour to authenticate users
  via SSH public keys stored in the database.
  """

  @behaviour :ssh_server_key_api

  require Logger

  alias DdexDeliveryService.SFTP.KeyAuth

  @impl true
  def host_key(algorithm, opts) do
    :ssh_file.host_key(algorithm, opts)
  end

  @impl true
  def is_auth_key(public_key, username, _opts) do
    user = to_string(username)
    KeyAuth.authenticate(user, public_key)
  end
end
