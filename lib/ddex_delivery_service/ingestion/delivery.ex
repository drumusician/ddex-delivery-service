defmodule DdexDeliveryService.Ingestion.Delivery do
  use Ash.Resource,
    otp_app: :ddex_delivery_service,
    domain: DdexDeliveryService.Ingestion,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  postgres do
    table "deliveries"
    repo DdexDeliveryService.Repo
  end

  json_api do
    type "delivery"

    includes releases: [],
             validation_results: []
  end

  graphql do
    type :delivery
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

  pub_sub do
    module DdexDeliveryServiceWeb.Endpoint
    prefix "delivery"

    publish :create, ["created"]
    publish :update, ["updated", :id]
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  attributes do
    uuid_primary_key :id

    attribute :source, :atom do
      constraints one_of: [:upload, :sftp]
      default :upload
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:received, :processing, :completed, :failed]
      default :received
      allow_nil? false
      public? true
    end

    attribute :ern_version, :string, public?: true
    attribute :message_id, :string, public?: true
    attribute :error_summary, :string, public?: true
    attribute :original_filename, :string, public?: true
    attribute :completed_at, :utc_datetime, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organization, DdexDeliveryService.Accounts.Organization do
      allow_nil? false
      public? false
    end

    has_many :validation_results, DdexDeliveryService.Ingestion.ValidationResult do
      public? true
    end

    has_many :releases, DdexDeliveryService.Catalog.Release do
      public? true
    end
  end
end
