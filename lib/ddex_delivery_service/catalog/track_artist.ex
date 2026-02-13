defmodule DdexDeliveryService.Catalog.TrackArtist do
  use Ash.Resource,
    otp_app: :ddex_delivery_service,
    domain: DdexDeliveryService.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "track_artists"
    repo DdexDeliveryService.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    create :upsert do
      accept :*
      upsert? true
      upsert_identity :unique_track_artist
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

    attribute :role, :atom do
      constraints one_of: [:main, :featured, :remixer, :composer, :producer]
      default :main
      public? true
    end

    attribute :sequence_number, :integer, public?: true
  end

  relationships do
    belongs_to :organization, DdexDeliveryService.Accounts.Organization do
      allow_nil? false
      public? false
    end

    belongs_to :track, DdexDeliveryService.Catalog.Track do
      allow_nil? false
      public? true
    end

    belongs_to :artist, DdexDeliveryService.Catalog.Artist do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_track_artist, [:track_id, :artist_id]
  end
end
