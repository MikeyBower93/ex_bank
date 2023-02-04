defmodule ExBank.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :amount, :decimal, null: false
      add :state, :string, null: false, default: Atom.to_string(:pending)
      add :receiver_account_name, :string, null: false
      add :receiver_sort_code, :string, null: false
      add :receiver_account_number, :string, null: false
      add :payment_error_message, :string
      add :payment_idempotency_key, :string, null: false
      add :payment_job_id, :integer, null: false
      add :account_id, references(:accounts, on_delete: :nothing), null: false

      timestamps()
    end

    create index(:transactions, [:account_id])
    create index(:transactions, [:payment_idempotency_key])
    create index(:transactions, [:payment_job_id])
  end
end
