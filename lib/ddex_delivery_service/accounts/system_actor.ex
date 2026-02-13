defmodule DdexDeliveryService.Accounts.SystemActor do
  @moduledoc """
  A struct representing the system actor for internal operations.

  Used when background jobs, ingestion pipelines, or other internal
  processes need to perform authorized operations without a real user.
  """
  defstruct []
end
