defmodule DdexDeliveryService.Catalog.Track do
  use Ash.Resource,
    otp_app: :ddex_delivery_service,
    domain: DdexDeliveryService.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  postgres do
    table "tracks"
    repo DdexDeliveryService.Repo
  end

  json_api do
    type "track"

    includes artists: [],
             release: []
  end

  graphql do
    type :track
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    create :upsert do
      accept :*
      upsert? true
      upsert_identity :unique_isrc
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

    attribute :isrc, :string, public?: true
    attribute :duration, :integer, public?: true
    attribute :track_number, :integer, public?: true
    attribute :disc_number, :integer, default: 1, public?: true
    attribute :display_artist, :string, public?: true
    attribute :ddex_resource_reference, :string, public?: true

    attribute :p_line, DdexDeliveryService.Catalog.PLine, public?: true
    attribute :c_line, DdexDeliveryService.Catalog.CLine, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :release, DdexDeliveryService.Catalog.Release do
      allow_nil? false
      public? true
    end

    belongs_to :organization, DdexDeliveryService.Accounts.Organization do
      allow_nil? false
      public? false
    end

    many_to_many :artists, DdexDeliveryService.Catalog.Artist do
      through DdexDeliveryService.Catalog.TrackArtist
      source_attribute_on_join_resource :track_id
      destination_attribute_on_join_resource :artist_id
      public? true
    end
  end

  identities do
    identity :unique_isrc, [:isrc]
  end
end
