defmodule ExBank.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :customer_name, :string, null: false
      add :balance, :decimal, null: false, default: 0

      timestamps()
    end

    create constraint(:accounts, :balance_must_be_positive, check: "balance >= 0")
    unique_index(:accounts, :customer_name)
  end
end
