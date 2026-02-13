defmodule DdexDeliveryService.Catalog.Label do
  use Ash.Resource,
    otp_app: :ddex_delivery_service,
    domain: DdexDeliveryService.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  json_api do
    type "label"
  end

  graphql do
    type :label
  end

  postgres do
    table "labels"
    repo DdexDeliveryService.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :by_name do
      argument :name, :string, allow_nil?: false
      get? true

      filter expr(name == ^arg(:name))
    end

    create :upsert do
      accept [:name, :ddex_party_id]
      upsert? true
      upsert_identity :unique_name
      upsert_fields [:ddex_party_id]
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

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :ddex_party_id, :string, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organization, DdexDeliveryService.Accounts.Organization do
      allow_nil? false
      public? false
    end

    has_many :releases, DdexDeliveryService.Catalog.Release do
      public? true
    end
  end

  identities do
    identity :unique_name, [:name]
  end
end
