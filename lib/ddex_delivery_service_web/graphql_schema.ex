defmodule DdexDeliveryServiceWeb.GraphqlSchema do
  use Absinthe.Schema

  use AshGraphql,
    domains: [DdexDeliveryService.Catalog, DdexDeliveryService.Ingestion]

  import_types Absinthe.Plug.Types

  query do
  end

  mutation do
    # Custom Absinthe mutations can be placed here
  end

  subscription do
    # Custom Absinthe subscriptions can be placed here
  end
end
