defmodule DdexDeliveryService.Repo do
  use Ecto.Repo,
    otp_app: :ddex_delivery_service,
    adapter: Ecto.Adapters.Postgres
end
