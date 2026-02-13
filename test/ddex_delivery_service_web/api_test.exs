defmodule DdexDeliveryServiceWeb.ApiTest do
  use DdexDeliveryServiceWeb.ConnCase, async: true

  alias DdexDeliveryService.Ingestion.Ingest

  defp system_actor, do: %DdexDeliveryService.Accounts.SystemActor{}

  setup do
    org = DdexDeliveryService.DataCase.create_test_org!()
    tenant = org.id

    {:ok, delivery} = Ingest.ingest_sample(tenant)

    # Wait for Oban to process the job
    assert_receive_oban_job(delivery.id, tenant)

    # Reload the delivery to get the completed status
    delivery =
      DdexDeliveryService.Ingestion.get_delivery_by_id!(delivery.id, actor: system_actor(), tenant: tenant)

    releases =
      DdexDeliveryService.Catalog.list_releases!(
        query: [filter: [delivery_id: delivery.id]],
        actor: system_actor(),
        tenant: tenant
      )

    release = hd(releases)
    %{delivery: delivery, release: release, tenant: tenant}
  end

  defp assert_receive_oban_job(delivery_id, tenant) do
    # Drain the Oban queue synchronously for testing
    Oban.drain_queue(queue: :default)

    delivery =
      DdexDeliveryService.Ingestion.get_delivery_by_id!(delivery_id, actor: system_actor(), tenant: tenant)

    assert delivery.status == :completed
  end

  defp authenticated_conn(conn, tenant) do
    # Set the current_user assign so the router's :set_actor plug picks it up.
    # Also set the tenant for Ash multitenancy.
    actor = %DdexDeliveryService.Accounts.SystemActor{}

    conn
    |> Plug.Conn.assign(:current_user, actor)
    |> Ash.PlugHelpers.set_tenant(tenant)
  end

  describe "JSON:API" do
    test "GET /api/json/releases returns releases", %{conn: conn, release: release, tenant: tenant} do
      conn =
        conn
        |> authenticated_conn(tenant)
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/releases")

      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
      assert length(data) >= 1

      ids = Enum.map(data, & &1["id"])
      assert release.id in ids
    end

    test "GET /api/json/releases/:id returns a release with attributes", %{
      conn: conn,
      release: release,
      tenant: tenant
    } do
      conn =
        conn
        |> authenticated_conn(tenant)
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/releases/#{release.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == release.id
      assert data["type"] == "release"
      assert data["attributes"]["title"] == "Signals from the Deep"
      assert data["attributes"]["upc"] == "5400123456789"
      assert data["attributes"]["display_artist"] == "Aurora Waves"
    end

    test "GET /api/json/releases/:id?include=tracks,artists includes related resources", %{
      conn: conn,
      release: release,
      tenant: tenant
    } do
      conn =
        conn
        |> authenticated_conn(tenant)
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/releases/#{release.id}?include=tracks,artists")

      assert %{"data" => data, "included" => included} = json_response(conn, 200)
      assert data["id"] == release.id

      types = Enum.map(included, & &1["type"]) |> Enum.uniq() |> Enum.sort()
      assert "artist" in types
      assert "track" in types
    end

    test "GET /api/json/tracks returns tracks", %{conn: conn, tenant: tenant} do
      conn =
        conn
        |> authenticated_conn(tenant)
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/tracks")

      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) >= 10
    end

    test "GET /api/json/artists returns artists", %{conn: conn, tenant: tenant} do
      conn =
        conn
        |> authenticated_conn(tenant)
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/artists")

      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) >= 1
    end

    test "GET /api/json/labels returns labels", %{conn: conn, tenant: tenant} do
      conn =
        conn
        |> authenticated_conn(tenant)
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/labels")

      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) >= 1
      assert hd(data)["attributes"]["name"] == "Neon Harbor Records"
    end

    test "GET /api/json/deliveries returns deliveries", %{conn: conn, delivery: delivery, tenant: tenant} do
      conn =
        conn
        |> authenticated_conn(tenant)
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/deliveries")

      assert %{"data" => data} = json_response(conn, 200)
      ids = Enum.map(data, & &1["id"])
      assert delivery.id in ids
    end

    test "GET /api/json/deliveries/:id?include=releases includes releases", %{
      conn: conn,
      delivery: delivery,
      tenant: tenant
    } do
      conn =
        conn
        |> authenticated_conn(tenant)
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/deliveries/#{delivery.id}?include=releases")

      assert %{"data" => data, "included" => included} = json_response(conn, 200)
      assert data["id"] == delivery.id
      assert Enum.any?(included, &(&1["type"] == "release"))
    end

    test "GET /api/json/releases without auth returns error", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/json/releases")

      # Without auth, there's no tenant context, so tenant-scoped resources return an error
      assert %{"errors" => _} = json_response(conn, 400)
    end
  end

  describe "GraphQL" do
    test "listReleases query returns releases", %{conn: conn, release: release, tenant: tenant} do
      query = """
      {
        listReleases {
          results {
            id
            title
            upc
            displayArtist
            releaseType
          }
        }
      }
      """

      conn =
        conn
        |> authenticated_conn(tenant)
        |> put_req_header("content-type", "application/json")
        |> post("/gql", Jason.encode!(%{query: query}))

      assert %{"data" => %{"listReleases" => %{"results" => results}}} = json_response(conn, 200)
      assert length(results) >= 1

      ids = Enum.map(results, & &1["id"])
      assert release.id in ids

      r = Enum.find(results, &(&1["id"] == release.id))
      assert r["title"] == "Signals from the Deep"
      assert r["upc"] == "5400123456789"
    end

    test "getRelease query with nested tracks and artists", %{conn: conn, release: release, tenant: tenant} do
      query = """
      {
        getRelease(id: "#{release.id}") {
          id
          title
          tracks {
            id
            title
            isrc
            trackNumber
          }
          artists {
            id
            name
          }
          label {
            id
            name
          }
          deals {
            id
            commercialModel
            usageTypes
          }
        }
      }
      """

      conn =
        conn
        |> authenticated_conn(tenant)
        |> put_req_header("content-type", "application/json")
        |> post("/gql", Jason.encode!(%{query: query}))

      assert %{"data" => %{"getRelease" => data}} = json_response(conn, 200)
      assert data["title"] == "Signals from the Deep"
      assert length(data["tracks"]) == 10
      assert length(data["artists"]) >= 1
      assert hd(data["artists"])["name"] == "Aurora Waves"
      assert data["label"]["name"] == "Neon Harbor Records"
      assert length(data["deals"]) >= 1
      assert hd(data["deals"])["commercialModel"] == "PayAsYouGoModel"
    end

    test "listTracks query", %{conn: conn, tenant: tenant} do
      query = """
      {
        listTracks {
          results {
            id
            title
            isrc
            trackNumber
            displayArtist
          }
        }
      }
      """

      conn =
        conn
        |> authenticated_conn(tenant)
        |> put_req_header("content-type", "application/json")
        |> post("/gql", Jason.encode!(%{query: query}))

      assert %{"data" => %{"listTracks" => %{"results" => results}}} = json_response(conn, 200)
      assert length(results) >= 10
    end

    test "listDeliveries query", %{conn: conn, delivery: delivery, tenant: tenant} do
      query = """
      {
        listDeliveries {
          results {
            id
            status
            ernVersion
            originalFilename
          }
        }
      }
      """

      conn =
        conn
        |> authenticated_conn(tenant)
        |> put_req_header("content-type", "application/json")
        |> post("/gql", Jason.encode!(%{query: query}))

      assert %{"data" => %{"listDeliveries" => %{"results" => results}}} =
               json_response(conn, 200)

      ids = Enum.map(results, & &1["id"])
      assert delivery.id in ids
    end
  end
end
