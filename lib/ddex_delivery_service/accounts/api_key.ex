defmodule DdexDeliveryService.Accounts.ApiKey do
  use Ash.Resource,
    otp_app: :ddex_delivery_service,
    domain: DdexDeliveryService.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "api_keys"
    repo DdexDeliveryService.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  actions do
    defaults [:read, :destroy]

    read :lookup_by_hash do
      argument :key_hash, :string, allow_nil?: false
      get? true
      multitenancy :allow_global

      filter expr(key_hash == ^arg(:key_hash))
    end

    create :create do
      accept [:name, :scopes, :expires_at]

      change fn changeset, _context ->
        raw_key = generate_raw_key()
        key_hash = hash_key(raw_key)
        key_prefix = String.slice(raw_key, 0, 8)

        changeset
        |> Ash.Changeset.force_change_attribute(:key_hash, key_hash)
        |> Ash.Changeset.force_change_attribute(:key_prefix, key_prefix)
        |> Ash.Changeset.after_action(fn _changeset, api_key ->
          {:ok, %{api_key | __metadata__: Map.put(api_key.__metadata__, :raw_key, raw_key)}}
        end)
      end
    end

    update :touch_last_used do
      accept []

      change set_attribute(:last_used_at, &DateTime.utc_now/0)
    end
  end

  policies do
    bypass DdexDeliveryService.Checks.IsSystemActor do
      authorize_if always()
    end

    policy always() do
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :key_hash, :string do
      allow_nil? false
      public? false
      sensitive? true
    end

    attribute :key_prefix, :string do
      allow_nil? false
      public? true
    end

    attribute :scopes, {:array, :atom} do
      constraints items: [one_of: [:read, :write, :admin]]
      default [:read]
      public? true
    end

    attribute :expires_at, :utc_datetime_usec, public?: true
    attribute :last_used_at, :utc_datetime_usec, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organization, DdexDeliveryService.Accounts.Organization do
      allow_nil? false
      public? false
    end
  end

  identities do
    identity :unique_key_hash, [:key_hash]
  end

  defp generate_raw_key do
    "dds_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
  end

  defp hash_key(raw_key) do
    :crypto.hash(:sha256, raw_key) |> Base.encode16(case: :lower)
  end

  @doc """
  Hash a raw API key for lookup. Public so the auth plug can use it.
  """
  def hash_raw_key(raw_key) do
    :crypto.hash(:sha256, raw_key) |> Base.encode16(case: :lower)
  end
end
