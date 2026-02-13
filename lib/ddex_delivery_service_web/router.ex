defmodule DdexDeliveryServiceWeb.Router do
  use DdexDeliveryServiceWeb, :router

  import Oban.Web.Router
  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  # Health check for Fly.io — no auth, no session
  scope "/health" do
    pipe_through :api
    get "/", DdexDeliveryServiceWeb.HealthController, :index
  end

  pipeline :graphql do
    plug DdexDeliveryServiceWeb.Plugs.ApiKeyAuth
    plug :load_from_bearer
    plug :set_actor, :user
    plug DdexDeliveryServiceWeb.Plugs.SetTenant
    plug AshGraphql.Plug
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DdexDeliveryServiceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug DdexDeliveryServiceWeb.Plugs.ApiKeyAuth
    plug :load_from_bearer
    plug :set_actor, :user
    plug DdexDeliveryServiceWeb.Plugs.SetTenant
  end

  # Public routes (no auth required)
  scope "/", DdexDeliveryServiceWeb do
    pipe_through :browser

    live "/", LandingLive, :index
    live "/features", FeaturesLive, :index
    live "/demo", DemoLive, :index
  end

  # Authenticated routes
  scope "/", DdexDeliveryServiceWeb do
    pipe_through :browser

    ash_authentication_live_session :authenticated_routes do
      live "/dashboard", DashboardLive, :index
    end
  end

  scope "/api/json" do
    pipe_through [:api]

    forward "/swaggerui", OpenApiSpex.Plug.SwaggerUI,
      path: "/api/json/open_api",
      default_model_expand_depth: 4

    forward "/", DdexDeliveryServiceWeb.AshJsonApiRouter
  end

  scope "/gql" do
    pipe_through [:graphql]

    forward "/playground", Absinthe.Plug.GraphiQL,
      schema: Module.concat(["DdexDeliveryServiceWeb.GraphqlSchema"]),
      socket: Module.concat(["DdexDeliveryServiceWeb.GraphqlSocket"]),
      interface: :simple

    forward "/", Absinthe.Plug, schema: Module.concat(["DdexDeliveryServiceWeb.GraphqlSchema"])
  end

  scope "/", DdexDeliveryServiceWeb do
    pipe_through :browser

    auth_routes AuthController, DdexDeliveryService.Accounts.User, path: "/auth"
    sign_out_route AuthController

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{DdexDeliveryServiceWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    DdexDeliveryServiceWeb.AuthOverrides,
                    Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                overrides: [
                  DdexDeliveryServiceWeb.AuthOverrides,
                  Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                ]

    # Remove this if you do not use the confirmation strategy
    confirm_route DdexDeliveryService.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [
        DdexDeliveryServiceWeb.AuthOverrides,
        Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
      ]

    # Remove this if you do not use the magic link strategy.
    magic_sign_in_route(DdexDeliveryService.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [
        DdexDeliveryServiceWeb.AuthOverrides,
        Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
      ]
    )
  end

  # Other scopes may use custom stacks.
  # scope "/api", DdexDeliveryServiceWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:ddex_delivery_service, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: DdexDeliveryServiceWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    scope "/" do
      pipe_through :browser

      oban_dashboard("/oban")
    end
  end
end
