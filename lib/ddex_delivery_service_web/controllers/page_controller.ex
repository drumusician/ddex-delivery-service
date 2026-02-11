defmodule DdexDeliveryServiceWeb.PageController do
  use DdexDeliveryServiceWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
