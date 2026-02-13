defmodule DdexDeliveryService.Catalog.Deal do
  use Ash.Resource,
    otp_app: :ddex_delivery_service,
    domain: DdexDeliveryService.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  json_api do
    type "deal"
  end

  graphql do
    type :deal
  end

  postgres do
    table "deals"
    repo DdexDeliveryService.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    create :upsert do
      accept :*
      upsert? true
      upsert_identity :unique_release_deal
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

    attribute :commercial_model, :string, public?: true
    attribute :usage_types, {:array, :string}, default: [], public?: true
    attribute :territory_codes, {:array, :string}, default: [], public?: true
    attribute :start_date, :date, public?: true
    attribute :end_date, :date, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organization, DdexDeliveryService.Accounts.Organization do
      allow_nil? false
      public? false
    end

    belongs_to :release, DdexDeliveryService.Catalog.Release do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_release_deal, [:release_id, :commercial_model, :start_date]
  end
end
