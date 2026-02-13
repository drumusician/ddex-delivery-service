defmodule DdexDeliveryService.Accounts.SftpKey do
  use Ash.Resource,
    otp_app: :ddex_delivery_service,
    domain: DdexDeliveryService.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "sftp_keys"
    repo DdexDeliveryService.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :public_key, :fingerprint, :active, :organization_id]
    end

    update :update do
      accept [:name, :active]
    end

    read :active_keys do
      filter expr(active == true)
    end

    read :by_fingerprint do
      argument :fingerprint, :string, allow_nil?: false
      filter expr(fingerprint == ^arg(:fingerprint) and active == true)
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

    attribute :public_key, :string do
      allow_nil? false
      public? true
      constraints max_length: 4096
    end

    attribute :fingerprint, :string do
      allow_nil? false
      public? true
    end

    attribute :active, :boolean do
      default true
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organization, DdexDeliveryService.Accounts.Organization do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_fingerprint, [:fingerprint]
  end
end
