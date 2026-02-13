defmodule DdexDeliveryServiceWeb.Plugs.SetTenant do
  @moduledoc """
  Plug that sets the Ash tenant from the request.

  Reads the organization ID from:
  1. `X-Organization-Id` header
  2. Falls back to the user's sole organization (if they have exactly one)

  Sets the tenant via `Ash.PlugHelpers.set_tenant/2` so that
  AshJsonApi and AshGraphql automatically scope queries.
  """

  import Plug.Conn

  alias DdexDeliveryService.Accounts.SystemActor

  def init(opts), do: opts

  def call(conn, _opts) do
    actor = Ash.PlugHelpers.get_actor(conn)

    case actor do
      %SystemActor{} ->
        # System actor doesn't need tenant context for bypassed operations
        conn

      nil ->
        # No actor, no tenant
        conn

      user ->
        org_id = resolve_org_id(conn, user)

        if org_id do
          Ash.PlugHelpers.set_tenant(conn, org_id)
        else
          conn
        end
    end
  end

  defp resolve_org_id(conn, user) do
    # Check header first
    case get_req_header(conn, "x-organization-id") do
      [org_id] when org_id != "" ->
        if user_has_membership?(user, org_id) do
          org_id
        else
          nil
        end

      _ ->
        # Fall back to user's sole org
        get_sole_org_id(user)
    end
  end

  defp user_has_membership?(user, org_id) do
    case Ash.load(user, :memberships, actor: %SystemActor{}) do
      {:ok, user} ->
        Enum.any?(user.memberships, fn m ->
          to_string(m.organization_id) == to_string(org_id)
        end)

      _ ->
        false
    end
  end

  defp get_sole_org_id(user) do
    case Ash.load(user, :memberships, actor: %SystemActor{}) do
      {:ok, user} ->
        case user.memberships do
          [single] -> to_string(single.organization_id)
          _ -> nil
        end

      _ ->
        nil
    end
  end
end
