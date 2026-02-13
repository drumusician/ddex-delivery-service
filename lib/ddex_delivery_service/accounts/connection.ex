defmodule DdexDeliveryService.Accounts.Connection do
  use Ash.Resource,
    otp_app: :ddex_delivery_service,
    domain: DdexDeliveryService.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "connections"
    repo DdexDeliveryService.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:status, :supplier_id, :recipient_id]
    end

    update :update do
      accept [:status]
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

    attribute :status, :atom do
      constraints one_of: [:active, :pending, :suspended]
      default :active
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :supplier, DdexDeliveryService.Accounts.Organization do
      allow_nil? false
      public? true
    end

    belongs_to :recipient, DdexDeliveryService.Accounts.Organization do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_supplier_recipient, [:supplier_id, :recipient_id]
  end
end
