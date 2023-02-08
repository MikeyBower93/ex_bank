defmodule ExBank.Payments.Account do
  use Ecto.Schema
  import Ecto.Changeset

  schema "accounts" do
    field :balance, :decimal
    field :customer_name, :string
    field :account_name, :string
    field :account_number, :string
    field :account_sort_code, :string

    timestamps()
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:customer_name, :balance, :account_name, :account_number, :account_sort_code])
    |> validate_required([
      :customer_name,
      :balance,
      :account_name,
      :account_number,
      :account_sort_code
    ])
  end
end
