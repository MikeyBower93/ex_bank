defmodule ExBank.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :customer_name, :string
      add :balance, :decimal

      timestamps()
    end

    create constraint(:accounts, :balance_must_be_positive, check: "balance >= 0")
  end
end
