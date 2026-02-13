defmodule DdexDeliveryService.Checks.IsSystemActor do
  @moduledoc """
  Policy check that authorizes the SystemActor.

  Used as a bypass policy so internal system operations
  (background jobs, ingestion pipeline) can perform any action.
  """
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "actor is the system actor"

  @impl true
  def match?(%DdexDeliveryService.Accounts.SystemActor{}, _context, _opts), do: true
  def match?(_, _, _), do: false
end
