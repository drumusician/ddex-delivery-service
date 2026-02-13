defmodule DdexDeliveryService.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        DdexDeliveryService.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:ddex_delivery_service, :token_signing_secret)
  end
end
