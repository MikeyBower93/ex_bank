defmodule ExBank.Payments.CreatePaymentRequest do
  defstruct [:account_id, :amount, :to_account_number, :to_sort_code, :to_name]
  alias ExBank.Payments.CreatePaymentRequest

  @types %{
    account_id: :integer,
    amount: :decimal,
    to_account_number: :string,
    to_sort_code: :string,
    to_name: :string
  }

  def verify(%CreatePaymentRequest{} = create_payment_request) do
    {%CreatePaymentRequest{}, @types}
    |> Ecto.Changeset.cast(Map.from_struct(create_payment_request), Map.keys(@types))
    |> case do
      %{valid?: false, errors: errors} -> {:error, errors}
      _otherwise -> {:valid, create_payment_request}
    end
  end
end
