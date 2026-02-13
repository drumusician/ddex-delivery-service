# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs

require Ash.Query

actor = %DdexDeliveryService.Accounts.SystemActor{}

# Create a test user (magic link auth, so no password needed).
case DdexDeliveryService.Accounts.User
     |> Ash.Query.filter(email == "demo@ddex.test")
     |> Ash.read_one(actor: actor) do
  {:ok, nil} ->
    DdexDeliveryService.Repo.insert!(%DdexDeliveryService.Accounts.User{
      id: Ash.UUID.generate(),
      email: "demo@ddex.test"
    })

    IO.puts("Created test user: demo@ddex.test")

  {:ok, _user} ->
    IO.puts("Test user already exists: demo@ddex.test")
end

# Create the demo organization (supplier role — uploads DDEX packages)
demo_org =
  case DdexDeliveryService.Accounts.get_organization_by_slug("demo", actor: actor) do
    {:ok, org} ->
      IO.puts("Demo organization already exists")
      org

    _ ->
      {:ok, org} = DdexDeliveryService.Accounts.create_organization(
        %{name: "Demo Organization", slug: "demo", role: :supplier},
        actor: actor
      )
      IO.puts("Created demo organization (supplier)")
      org
  end

# Create a demo recipient organization
recipient_org =
  case DdexDeliveryService.Accounts.get_organization_by_slug("demo-recipient", actor: actor) do
    {:ok, org} ->
      IO.puts("Demo recipient organization already exists")
      org

    _ ->
      {:ok, org} = DdexDeliveryService.Accounts.create_organization(
        %{name: "Demo Recipient (DSP)", slug: "demo-recipient", role: :recipient},
        actor: actor
      )
      IO.puts("Created demo recipient organization")
      org
  end

# Create a connection between demo supplier and recipient
case DdexDeliveryService.Accounts.Connection
     |> Ash.Query.filter(supplier_id == ^demo_org.id and recipient_id == ^recipient_org.id)
     |> Ash.read_one(actor: actor) do
  {:ok, nil} ->
    {:ok, _conn} = DdexDeliveryService.Accounts.create_connection(
      %{supplier_id: demo_org.id, recipient_id: recipient_org.id, status: :active},
      actor: actor
    )
    IO.puts("Created demo connection (supplier -> recipient)")

  {:ok, _} ->
    IO.puts("Demo connection already exists")
end
