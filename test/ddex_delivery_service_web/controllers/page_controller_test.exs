defmodule DdexDeliveryServiceWeb.LandingLiveTest do
  use DdexDeliveryServiceWeb.ConnCase

  test "GET / renders landing page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "DDEX Delivery"
    assert html_response(conn, 200) =~ "Try the demo"
  end

  test "GET /demo renders demo page", %{conn: conn} do
    conn = get(conn, ~p"/demo")
    assert html_response(conn, 200) =~ "Interactive Demo"
  end
end
