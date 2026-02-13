defmodule DdexDeliveryService.Ingestion do
  use Ash.Domain,
    otp_app: :ddex_delivery_service,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain]

  json_api do
    routes do
      base_route "/deliveries", DdexDeliveryService.Ingestion.Delivery do
        get :read
        index :read
        related :releases, :read
        related :validation_results, :read
      end

      base_route "/validation-results", DdexDeliveryService.Ingestion.ValidationResult do
        get :read
        index :read
      end
    end
  end

  graphql do
    queries do
      get DdexDeliveryService.Ingestion.Delivery, :get_delivery, :read
      list DdexDeliveryService.Ingestion.Delivery, :list_deliveries, :read

      get DdexDeliveryService.Ingestion.ValidationResult, :get_validation_result, :read
      list DdexDeliveryService.Ingestion.ValidationResult, :list_validation_results, :read
    end
  end

  resources do
    resource DdexDeliveryService.Ingestion.Delivery do
      define :create_delivery, action: :create
      define :get_delivery_by_id, action: :read, get_by: [:id]
      define :update_delivery, action: :update
      define :list_deliveries, action: :read
    end

    resource DdexDeliveryService.Ingestion.ValidationResult do
      define :create_validation_result, action: :create
    end

    resource DdexDeliveryService.Ingestion.StoredFile do
      define :create_stored_file, action: :create
      define :update_stored_file, action: :update
      define :list_stored_files, action: :read
    end
  end
end
