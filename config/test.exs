import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :ex_bank, ExBank.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "ex_bank_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ex_bank, ExBankWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "A5cwVieTXL0gbIqcSyg7Q+O92iAOczDaBHoHrqG/sXX/BEiZrBpcTo4CuIXaPR/Z",
  server: false

# In test we don't send emails.
config :ex_bank, ExBank.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :ex_bank, Oban, testing: :manual

config :tesla, adapter: Tesla.Mock

config :logger, level: :debug
