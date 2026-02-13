defmodule DdexDeliveryServiceWeb.CsvController do
  use DdexDeliveryServiceWeb, :controller

  alias DdexDeliveryService.Export.Csv

  def tracks(conn, %{"delivery_id" => delivery_id}) do
    tenant = Ash.PlugHelpers.get_tenant(conn)

    case tenant do
      nil ->
        conn
        |> put_status(401)
        |> json(%{error: "Missing tenant context"})

      org_id ->
        case Csv.export_tracks(delivery_id, org_id) do
          {:ok, csv} ->
            send_csv(conn, csv, "tracks_#{delivery_id}.csv")

          {:error, %Ash.Error.Query.NotFound{}} ->
            conn |> put_status(404) |> json(%{error: "Delivery not found"})

          {:error, _reason} ->
            conn |> put_status(500) |> json(%{error: "Export failed"})
        end
    end
  end

  def releases(conn, %{"delivery_id" => delivery_id}) do
    tenant = Ash.PlugHelpers.get_tenant(conn)

    case tenant do
      nil ->
        conn
        |> put_status(401)
        |> json(%{error: "Missing tenant context"})

      org_id ->
        case Csv.export_releases(delivery_id, org_id) do
          {:ok, csv} ->
            send_csv(conn, csv, "releases_#{delivery_id}.csv")

          {:error, %Ash.Error.Query.NotFound{}} ->
            conn |> put_status(404) |> json(%{error: "Delivery not found"})

          {:error, _reason} ->
            conn |> put_status(500) |> json(%{error: "Export failed"})
        end
    end
  end

  defp send_csv(conn, csv, filename) do
    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, csv)
  end
end
