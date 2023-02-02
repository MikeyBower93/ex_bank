defmodule ExBank.Payments.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :amount, :decimal
    field :error, :string
    field :receiver, :string
    field :receiver_account_number, :string
    field :receiver_sort_code, :string
    field :state, :string
    field :account_id, :id

    timestamps()
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:amount, :state, :receiver, :receiver_sort_code, :receiver_account_number, :error])
    |> validate_required([:amount, :state, :receiver, :receiver_sort_code, :receiver_account_number, :error])
  end
end
