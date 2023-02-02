defmodule ExBank.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :amount, :decimal
      add :state, :string
      add :receiver, :string
      add :receiver_sort_code, :string
      add :receiver_account_number, :string
      add :error, :string
      add :job_idempotency_key, :string
      add :account_id, references(:accounts, on_delete: :nothing)

      timestamps()
    end

    create index(:transactions, [:account_id])
  end
end
