defmodule DdexDeliveryService.Accounts.Membership do
  use Ash.Resource,
    otp_app: :ddex_delivery_service,
    domain: DdexDeliveryService.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "memberships"
    repo DdexDeliveryService.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:role, :user_id, :organization_id]
    end

    update :update do
      accept [:role]
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

    attribute :role, :atom do
      constraints one_of: [:owner, :admin, :member, :viewer]
      default :member
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, DdexDeliveryService.Accounts.User do
      allow_nil? false
    end

    belongs_to :organization, DdexDeliveryService.Accounts.Organization do
      allow_nil? false
    end
  end

  identities do
    identity :unique_user_org, [:user_id, :organization_id]
  end
end
