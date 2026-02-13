# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ash_oban, pro?: false

config :ddex_delivery_service, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [default: 10],
  repo: DdexDeliveryService.Repo,
  plugins: [{Oban.Plugins.Cron, []}]

config :mime,
  extensions: %{
    "json" => "application/vnd.api+json",
    "flac" => "audio/flac",
    "aac" => "audio/aac"
  },
  types: %{
    "application/vnd.api+json" => ["json"],
    "audio/flac" => ["flac"],
    "audio/aac" => ["aac"]
  }

config :ash_json_api,
  show_public_calculations_when_loaded?: false,
  authorize_update_destroy_with_error?: true

config :ash_graphql, authorize_update_destroy_with_error?: true

config :ash,
  allow_forbidden_field_for_relationships_by_default?: true,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false],
  keep_read_action_loads_when_loading?: false,
  default_actions_require_atomic?: true,
  read_action_after_action_hooks_in_order?: true,
  bulk_actions_default_to_errors?: true,
  transaction_rollback_on_error?: true,
  known_types: [AshPostgres.Timestamptz, AshPostgres.TimestamptzUsec]

config :spark,
  formatter: [
    remove_parens?: true,
    "Ash.Resource": [
      section_order: [
        :authentication,
        :token,
        :user_identity,
        :postgres,
        :json_api,
        :graphql,
        :resource,
        :code_interface,
        :actions,
        :policies,
        :pub_sub,
        :preparations,
        :changes,
        :validations,
        :multitenancy,
        :attributes,
        :relationships,
        :calculations,
        :aggregates,
        :identities
      ]
    ],
    "Ash.Domain": [
      section_order: [
        :json_api,
        :graphql,
        :resources,
        :policies,
        :authorization,
        :domain,
        :execution
      ]
    ]
  ]

config :ddex_delivery_service,
  ecto_repos: [DdexDeliveryService.Repo],
  generators: [timestamp_type: :utc_datetime],
  ash_domains: [DdexDeliveryService.Accounts, DdexDeliveryService.Catalog, DdexDeliveryService.Ingestion],
  ash_authentication: [return_error_on_invalid_magic_link_token?: true]

# Configure SFTP server
config :ddex_delivery_service, :sftp,
  enabled: true,
  port: 2222,
  upload_root: "priv/sftp/uploads",
  host_key_dir: "priv/sftp"

# Configure the endpoint
config :ddex_delivery_service, DdexDeliveryServiceWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: DdexDeliveryServiceWeb.ErrorHTML, json: DdexDeliveryServiceWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: DdexDeliveryService.PubSub,
  live_view: [signing_salt: "WN7Xck6V"]

# Configure file storage (S3-compatible, e.g. Tigris)
config :ddex_delivery_service,
  storage_bucket: System.get_env("STORAGE_BUCKET", "ddex-deliveries")

config :ex_aws,
  json_codec: Jason,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role],
  region: System.get_env("AWS_REGION", "auto")

config :ex_aws, :s3,
  scheme: "https://",
  host: System.get_env("AWS_S3_HOST"),
  port: 443

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :ddex_delivery_service, DdexDeliveryService.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  ddex_delivery_service: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  ddex_delivery_service: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
