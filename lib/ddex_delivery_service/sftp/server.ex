defmodule DdexDeliveryService.SFTP.Server do
  @moduledoc """
  GenServer that starts an SSH daemon with SFTP subsystem.

  Uses Erlang's built-in `:ssh` and `:ssh_sftpd` — no external dependencies.
  Each organization gets an isolated upload directory based on their slug.

  ## Configuration

      config :ddex_delivery_service, :sftp,
        enabled: true,
        port: 2222,
        upload_root: "priv/sftp/uploads",
        host_key_dir: "priv/sftp"
  """

  use GenServer
  require Logger

  alias DdexDeliveryService.SFTP.FileHandler

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    config = Application.get_env(:ddex_delivery_service, :sftp, [])

    if Keyword.get(config, :enabled, true) do
      port = Keyword.get(config, :port, 2222)
      host_key_dir = resolve_path(Keyword.get(config, :host_key_dir, "priv/sftp"))

      # Ensure directories exist
      File.mkdir_p!(host_key_dir)
      File.mkdir_p!(FileHandler.upload_root())

      # Generate host key if missing
      ensure_host_key(host_key_dir)

      # Start the SSH daemon
      case start_daemon(port, host_key_dir) do
        {:ok, daemon_ref} ->
          Logger.info("SFTP server started on port #{port}")
          {:ok, %{daemon_ref: daemon_ref, port: port}}

        {:error, reason} ->
          Logger.error("Failed to start SFTP server: #{inspect(reason)}")
          {:ok, %{daemon_ref: nil, port: port, error: reason}}
      end
    else
      Logger.info("SFTP server disabled by configuration")
      {:ok, %{daemon_ref: nil, port: nil}}
    end
  end

  @impl true
  def terminate(_reason, %{daemon_ref: ref}) when ref != nil do
    :ssh.stop_daemon(ref)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  defp start_daemon(port, host_key_dir) do
    ssh_opts = [
      {:system_dir, String.to_charlist(host_key_dir)},
      {:auth_methods, ~c"publickey"},
      {:pk_check_user, true},
      {:key_cb, {DdexDeliveryService.SFTP.SSHKeyCallback, []}},
      {:subsystems, [
        :ssh_sftpd.subsystem_spec([
          {:cwd, String.to_charlist(FileHandler.upload_root())},
          {:root, String.to_charlist(FileHandler.upload_root())}
        ])
      ]},
      {:no_auth_needed, false}
    ]

    :ssh.daemon(port, ssh_opts)
  end

  defp ensure_host_key(host_key_dir) do
    rsa_key_path = Path.join(host_key_dir, "ssh_host_rsa_key")

    unless File.exists?(rsa_key_path) do
      Logger.info("Generating SSH host RSA key at #{rsa_key_path}")
      generate_host_key(rsa_key_path)
    end
  end

  defp generate_host_key(key_path) do
    # Generate a 2048-bit RSA key using Erlang's :public_key module
    rsa_key = :public_key.generate_key({:rsa, 2048, 65537})

    # Encode as PEM
    pem_entry = :public_key.pem_entry_encode(:RSAPrivateKey, rsa_key)
    pem = :public_key.pem_encode([pem_entry])

    File.write!(key_path, pem, [:write])
    File.chmod!(key_path, 0o600)

    # Extract and write public key
    {:RSAPrivateKey, _, modulus, public_exponent, _, _, _, _, _, _, _} = rsa_key
    pub_key = {:RSAPublicKey, modulus, public_exponent}
    pub_entry = :public_key.pem_entry_encode(:RSAPublicKey, pub_key)
    pub_pem = :public_key.pem_encode([pub_entry])
    File.write!(key_path <> ".pub", pub_pem)

    Logger.info("SSH host key generated successfully")
  end

  defp resolve_path(path) do
    if Path.type(path) == :absolute do
      path
    else
      Application.app_dir(:ddex_delivery_service, path)
    end
  end
end
