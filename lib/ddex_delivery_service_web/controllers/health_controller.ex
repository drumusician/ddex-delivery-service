defmodule DdexDeliveryServiceWeb.HealthController do
  use DdexDeliveryServiceWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
