defmodule ExBank.Repo do
  use Ecto.Repo,
    otp_app: :ex_bank,
    adapter: Ecto.Adapters.Postgres
end
