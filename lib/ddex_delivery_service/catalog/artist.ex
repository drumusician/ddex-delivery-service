defmodule DdexDeliveryService.Catalog.Artist do
  use Ash.Resource,
    otp_app: :ddex_delivery_service,
    domain: DdexDeliveryService.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  postgres do
    table "artists"
    repo DdexDeliveryService.Repo
  end

  json_api do
    type "artist"

    includes releases: [],
             tracks: []
  end

  graphql do
    type :artist
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :by_name do
      argument :name, :string, allow_nil?: false
      get? true

      filter expr(name == ^arg(:name))
    end

    create :upsert do
      accept [:name, :isni, :ddex_party_id]
      upsert? true
      upsert_identity :unique_name
      upsert_fields [:isni, :ddex_party_id]
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

    attribute :isni, :string, public?: true
    attribute :ddex_party_id, :string, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    many_to_many :releases, DdexDeliveryService.Catalog.Release do
      through DdexDeliveryService.Catalog.ReleaseArtist
      source_attribute_on_join_resource :artist_id
      destination_attribute_on_join_resource :release_id
      public? true
    end

    many_to_many :tracks, DdexDeliveryService.Catalog.Track do
      through DdexDeliveryService.Catalog.TrackArtist
      source_attribute_on_join_resource :artist_id
      destination_attribute_on_join_resource :track_id
      public? true
    end
  end

  identities do
    identity :unique_name, [:name]
  end
end
