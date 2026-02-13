defmodule DdexDeliveryServiceWeb.DemoCsvController do
  use DdexDeliveryServiceWeb, :controller

  alias DdexDeliveryService.Export.Csv

  defp system_actor, do: %DdexDeliveryService.Accounts.SystemActor{}

  def tracks(conn, %{"delivery_id" => delivery_id}) do
    case DdexDeliveryService.Accounts.get_organization_by_slug("demo", actor: system_actor()) do
      {:ok, org} ->
        case Csv.export_tracks(delivery_id, org.id) do
          {:ok, csv} ->
            conn
            |> put_resp_content_type("text/csv")
            |> put_resp_header("content-disposition", ~s(attachment; filename="tracks_#{delivery_id}.csv"))
            |> send_resp(200, csv)

          {:error, _reason} ->
            conn |> put_status(404) |> text("Delivery not found")
        end

      _ ->
        conn |> put_status(404) |> text("Demo organization not found")
    end
  end
end
