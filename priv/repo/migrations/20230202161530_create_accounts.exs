defmodule ExBank.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :customer_name, :string, null: false
      add :account_name, :string, null: false
      add :account_number, :string, null: false
      add :account_sort_code, :string, null: false
      add :balance, :numeric, null: false, default: 0

      timestamps()
    end

    create constraint(:accounts, :balance_must_be_positive, check: "balance >= 0")
    create unique_index(:accounts, :customer_name)
    create unique_index(:accounts, [:account_name, :account_number, :account_sort_code])
  end
end
