defmodule DdexDeliveryService.Catalog.Release do
  use Ash.Resource,
    otp_app: :ddex_delivery_service,
    domain: DdexDeliveryService.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  postgres do
    table "releases"
    repo DdexDeliveryService.Repo
  end

  json_api do
    type "release"

    includes tracks: [],
             artists: [],
             label: [],
             deals: [],
             territory_releases: [],
             delivery: []
  end

  graphql do
    type :release
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    create :upsert do
      accept :*
      upsert? true
      upsert_identity :unique_upc
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

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :subtitle, :string, public?: true

    attribute :release_type, :atom do
      constraints one_of: [:album, :single, :ep, :compilation, :other]
      default :album
      public? true
    end

    attribute :upc, :string, public?: true
    attribute :catalog_number, :string, public?: true
    attribute :grid, :string, public?: true
    attribute :release_date, :date, public?: true
    attribute :original_release_date, :date, public?: true
    attribute :duration, :integer, public?: true
    attribute :display_artist, :string, public?: true

    attribute :p_line, DdexDeliveryService.Catalog.PLine, public?: true
    attribute :c_line, DdexDeliveryService.Catalog.CLine, public?: true

    attribute :parental_warning, :atom do
      constraints one_of: [:explicit, :not_explicit, :unknown]
      default :unknown
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:draft, :active, :taken_down]
      default :active
      public? true
    end

    attribute :ddex_release_reference, :string, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :label, DdexDeliveryService.Catalog.Label do
      public? true
    end

    belongs_to :delivery, DdexDeliveryService.Ingestion.Delivery do
      public? true
    end

    has_many :tracks, DdexDeliveryService.Catalog.Track do
      public? true
    end

    has_many :deals, DdexDeliveryService.Catalog.Deal do
      public? true
    end

    has_many :territory_releases, DdexDeliveryService.Catalog.TerritoryRelease do
      public? true
    end

    belongs_to :organization, DdexDeliveryService.Accounts.Organization do
      allow_nil? false
      public? false
    end

    many_to_many :artists, DdexDeliveryService.Catalog.Artist do
      through DdexDeliveryService.Catalog.ReleaseArtist
      source_attribute_on_join_resource :release_id
      destination_attribute_on_join_resource :artist_id
      public? true
    end
  end

  identities do
    identity :unique_upc, [:upc]
  end
end
