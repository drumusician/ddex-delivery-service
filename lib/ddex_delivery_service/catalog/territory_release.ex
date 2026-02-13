defmodule DdexDeliveryService.Catalog.TerritoryRelease do
  use Ash.Resource,
    otp_app: :ddex_delivery_service,
    domain: DdexDeliveryService.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  json_api do
    type "territory-release"
  end

  graphql do
    type :territory_release
  end

  postgres do
    table "territory_releases"
    repo DdexDeliveryService.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    create :upsert do
      accept :*
      upsert? true
      upsert_identity :unique_release_territory
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

    attribute :territory_code, :string do
      allow_nil? false
      public? true
    end

    attribute :title, :string, public?: true
    attribute :display_artist, :string, public?: true
    attribute :label_name, :string, public?: true
    attribute :genre, :string, public?: true
    attribute :sub_genre, :string, public?: true
    attribute :language_code, :string, public?: true

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
    identity :unique_release_territory, [:release_id, :territory_code]
  end
end
