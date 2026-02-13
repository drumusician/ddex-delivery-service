defmodule DdexDeliveryService.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    sftp_children =
      if Application.get_env(:ddex_delivery_service, :sftp, []) |> Keyword.get(:enabled, true) do
        [
          {DdexDeliveryService.SFTP.FileWatcher, []},
          {DdexDeliveryService.SFTP.Server, []}
        ]
      else
        []
      end

    children =
      [
        DdexDeliveryServiceWeb.Telemetry,
        DdexDeliveryService.Repo,
        {DNSCluster,
         query: Application.get_env(:ddex_delivery_service, :dns_cluster_query) || :ignore},
        {Oban,
         AshOban.config(
           Application.fetch_env!(:ddex_delivery_service, :ash_domains),
           Application.fetch_env!(:ddex_delivery_service, Oban)
         )},
        {Phoenix.PubSub, name: DdexDeliveryService.PubSub},
        # Start to serve requests, typically the last entry
        DdexDeliveryServiceWeb.Endpoint,
        {Absinthe.Subscription, DdexDeliveryServiceWeb.Endpoint},
        AshGraphql.Subscription.Batcher,
        {AshAuthentication.Supervisor, [otp_app: :ddex_delivery_service]}
      ] ++ sftp_children

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DdexDeliveryService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DdexDeliveryServiceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
