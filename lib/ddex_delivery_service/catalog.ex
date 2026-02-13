defmodule DdexDeliveryService.Catalog do
  use Ash.Domain,
    otp_app: :ddex_delivery_service,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain]

  json_api do
    routes do
      base_route "/releases", DdexDeliveryService.Catalog.Release do
        get :read
        index :read
        related :tracks, :read
        related :artists, :read
        related :deals, :read
        related :label, :read
        related :territory_releases, :read
      end

      base_route "/tracks", DdexDeliveryService.Catalog.Track do
        get :read
        index :read
        related :artists, :read
        related :release, :read
      end

      base_route "/artists", DdexDeliveryService.Catalog.Artist do
        get :read
        index :read
        related :releases, :read
      end

      base_route "/labels", DdexDeliveryService.Catalog.Label do
        get :read
        index :read
        related :releases, :read
      end

      base_route "/deals", DdexDeliveryService.Catalog.Deal do
        get :read
        index :read
      end

      base_route "/territory-releases", DdexDeliveryService.Catalog.TerritoryRelease do
        get :read
        index :read
      end
    end
  end

  graphql do
    queries do
      get DdexDeliveryService.Catalog.Release, :get_release, :read
      list DdexDeliveryService.Catalog.Release, :list_releases, :read

      get DdexDeliveryService.Catalog.Track, :get_track, :read
      list DdexDeliveryService.Catalog.Track, :list_tracks, :read

      get DdexDeliveryService.Catalog.Artist, :get_artist, :read
      list DdexDeliveryService.Catalog.Artist, :list_artists, :read

      get DdexDeliveryService.Catalog.Label, :get_label, :read
      list DdexDeliveryService.Catalog.Label, :list_labels, :read

      get DdexDeliveryService.Catalog.Deal, :get_deal, :read
      list DdexDeliveryService.Catalog.Deal, :list_deals, :read

      get DdexDeliveryService.Catalog.TerritoryRelease, :get_territory_release, :read
      list DdexDeliveryService.Catalog.TerritoryRelease, :list_territory_releases, :read
    end
  end

  resources do
    resource DdexDeliveryService.Catalog.Release do
      define :create_release, action: :create
      define :get_release_by_id, action: :read, get_by: [:id]
      define :list_releases, action: :read
    end

    resource DdexDeliveryService.Catalog.Track do
      define :create_track, action: :create
      define :list_tracks, action: :read
    end

    resource DdexDeliveryService.Catalog.Artist do
      define :create_artist, action: :create
      define :upsert_artist, action: :upsert
      define :get_artist_by_name, action: :by_name, args: [:name]
      define :list_artists, action: :read
    end

    resource DdexDeliveryService.Catalog.ReleaseArtist do
      define :create_release_artist, action: :create
    end

    resource DdexDeliveryService.Catalog.TrackArtist do
      define :create_track_artist, action: :create
    end

    resource DdexDeliveryService.Catalog.Label do
      define :create_label, action: :create
      define :upsert_label, action: :upsert
      define :get_label_by_name, action: :by_name, args: [:name]
    end

    resource DdexDeliveryService.Catalog.Deal do
      define :create_deal, action: :create
    end

    resource DdexDeliveryService.Catalog.TerritoryRelease do
      define :create_territory_release, action: :create
    end
  end
end
