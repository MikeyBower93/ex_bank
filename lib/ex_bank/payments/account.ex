defmodule ExBank.Payments.Account do
  use Ecto.Schema
  import Ecto.Changeset

  schema "accounts" do
    field :balance, :decimal
    field :customer_name, :string

    timestamps()
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:customer_name, :balance])
    |> validate_required([:customer_name, :balance])
  end
end
