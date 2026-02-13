defmodule DdexDeliveryServiceWeb.AshJsonApiRouter do
  use AshJsonApi.Router,
    domains: [DdexDeliveryService.Catalog, DdexDeliveryService.Ingestion],
    open_api: "/open_api"
end
