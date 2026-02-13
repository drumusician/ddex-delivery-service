defmodule DdexDeliveryService.Accounts.Organization do
  use Ash.Resource,
    otp_app: :ddex_delivery_service,
    domain: DdexDeliveryService.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "organizations"
    repo DdexDeliveryService.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :slug, :ddex_party_id, :status, :role]
    end

    update :update do
      accept [:name, :ddex_party_id, :status, :role]
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

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :ddex_party_id, :string, public?: true

    attribute :role, :atom do
      constraints one_of: [:supplier, :recipient]
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:active, :suspended, :trial]
      default :trial
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :memberships, DdexDeliveryService.Accounts.Membership
    has_many :sftp_keys, DdexDeliveryService.Accounts.SftpKey

    has_many :supplier_connections, DdexDeliveryService.Accounts.Connection do
      destination_attribute :supplier_id
    end

    has_many :recipient_connections, DdexDeliveryService.Accounts.Connection do
      destination_attribute :recipient_id
    end
  end

  identities do
    identity :unique_slug, [:slug]
  end
end
