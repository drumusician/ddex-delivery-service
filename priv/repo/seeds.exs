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

# Create the demo organization
case DdexDeliveryService.Accounts.get_organization_by_slug("demo", actor: actor) do
  {:ok, _org} ->
    IO.puts("Demo organization already exists")

  _ ->
    {:ok, _org} = DdexDeliveryService.Accounts.create_organization(
      %{name: "Demo Organization", slug: "demo"},
      actor: actor
    )
    IO.puts("Created demo organization")
end
