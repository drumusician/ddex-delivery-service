defmodule DdexDeliveryService.Ingestion.StoredFile do
  use Ash.Resource,
    otp_app: :ddex_delivery_service,
    domain: DdexDeliveryService.Ingestion,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "stored_files"
    repo DdexDeliveryService.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :bucket,
        :key,
        :filename,
        :content_type,
        :byte_size,
        :checksum_sha256,
        :file_type,
        :status,
        :delivery_id
      ]
    end

    update :update do
      accept [:status, :purged_at]
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

    attribute :bucket, :string do
      allow_nil? false
      public? true
    end

    attribute :key, :string do
      allow_nil? false
      public? true
    end

    attribute :filename, :string do
      allow_nil? false
      public? true
    end

    attribute :content_type, :string, public?: true

    attribute :byte_size, :integer, public?: true

    attribute :checksum_sha256, :string, public?: true

    attribute :file_type, :atom do
      constraints one_of: [:audio, :artwork, :xml]
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:uploading, :stored, :purged]
      default :uploading
      allow_nil? false
      public? true
    end

    attribute :purged_at, :utc_datetime_usec, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organization, DdexDeliveryService.Accounts.Organization do
      allow_nil? false
      public? false
    end

    belongs_to :delivery, DdexDeliveryService.Ingestion.Delivery do
      allow_nil? false
      public? true
    end
  end
end
