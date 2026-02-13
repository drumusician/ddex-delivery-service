import Config
config :ddex_delivery_service, Oban, testing: :manual
config :ddex_delivery_service, token_signing_secret: "zd1kh+OY1OOiSImogUdP7QJ7f0cg2KJ5"
config :bcrypt_elixir, log_rounds: 1
config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

# Fake S3 credentials for test (no actual S3 calls are made)
config :ex_aws,
  access_key_id: "test-key-id",
  secret_access_key: "test-secret-key",
  region: "us-east-1"

config :ex_aws, :s3,
  scheme: "https://",
  host: "s3.test.example.com",
  port: 443

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :ddex_delivery_service, DdexDeliveryService.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "ddex_delivery_service_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ddex_delivery_service, DdexDeliveryServiceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "1pXs8xIQSMNCzLy2uXm9DQdmtDG5WBzlqFxCXg++8AiBZ3BUYC3y8hFM0fksgqRi",
  server: false

# In test we don't send emails
config :ddex_delivery_service, DdexDeliveryService.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
