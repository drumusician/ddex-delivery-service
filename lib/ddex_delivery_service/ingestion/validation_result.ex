defmodule DdexDeliveryService.Ingestion.ValidationResult do
  use Ash.Resource,
    otp_app: :ddex_delivery_service,
    domain: DdexDeliveryService.Ingestion,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  json_api do
    type "validation-result"
  end

  graphql do
    type :validation_result
  end

  postgres do
    table "validation_results"
    repo DdexDeliveryService.Repo
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
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

    attribute :severity, :atom do
      constraints one_of: [:error, :warning, :info]
      allow_nil? false
      public? true
    end

    attribute :rule_code, :string, public?: true
    attribute :message, :string, public?: true
    attribute :field_name, :string, public?: true

    create_timestamp :inserted_at
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
