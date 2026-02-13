defmodule DdexDeliveryServiceWeb.Plugs.ApiKeyAuth do
  @moduledoc """
  Plug that authenticates requests using API keys.

  Looks for `Authorization: Bearer dds_...` header. If the token starts
  with `dds_`, it's treated as an API key. Otherwise, the request falls
  through to the next auth mechanism (JWT via AshAuthentication).

  On success, sets:
  - actor (the API key record, which satisfies `actor_present?`)
  - tenant (the API key's organization_id)
  """

  import Plug.Conn

  alias DdexDeliveryService.Accounts.ApiKey

  defp system_actor, do: %DdexDeliveryService.Accounts.SystemActor{}

  def init(opts), do: opts

  def call(conn, _opts) do
    with [bearer] <- get_req_header(conn, "authorization"),
         "Bearer " <> token <- bearer,
         true <- String.starts_with?(token, "dds_") do
      authenticate_api_key(conn, token)
    else
      _ -> conn
    end
  end

  defp authenticate_api_key(conn, raw_key) do
    key_hash = ApiKey.hash_raw_key(raw_key)

    case lookup_api_key(key_hash) do
      {:ok, api_key} ->
        if expired?(api_key) do
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(401, Jason.encode!(%{error: "API key expired"}))
          |> halt()
        else
          touch_last_used(api_key)

          conn
          |> Plug.Conn.assign(:current_user, api_key)
          |> Ash.PlugHelpers.set_actor(api_key)
          |> Ash.PlugHelpers.set_tenant(api_key.organization_id)
        end

      :error ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "Invalid API key"}))
        |> halt()
    end
  end

  defp lookup_api_key(key_hash) do
    case DdexDeliveryService.Accounts.lookup_api_key_by_hash(key_hash, actor: system_actor()) do
      {:ok, api_key} -> {:ok, api_key}
      _ -> :error
    end
  end

  defp expired?(%{expires_at: nil}), do: false

  defp expired?(%{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  defp touch_last_used(api_key) do
    Task.start(fn ->
      api_key
      |> Ash.Changeset.for_update(:touch_last_used, %{}, actor: system_actor(), tenant: api_key.organization_id)
      |> Ash.update(actor: system_actor(), tenant: api_key.organization_id)
    end)
  end
end
