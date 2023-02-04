defmodule ExBank.Payments.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :amount, :decimal
    field :error, :string
    field :receiver, :string
    field :receiver_account_number, :string
    field :receiver_sort_code, :string
    field :state, Ecto.Enum, values: [:pending, :failed, :succeeding]
    field :account_id, :id
    field :payment_idempotency_key, :string
    field :payment_job_id, :integer

    timestamps()
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :amount,
      :state,
      :receiver,
      :receiver_sort_code,
      :receiver_account_number,
      :error,
      :payment_idempotency_key,
      :payment_job_id,
      :account_id
    ])
    |> validate_required([
      :amount,
      :state,
      :receiver,
      :receiver_sort_code,
      :receiver_account_number,
      :payment_idempotency_key,
      :payment_job_id,
      :account_id
    ])
  end
end
