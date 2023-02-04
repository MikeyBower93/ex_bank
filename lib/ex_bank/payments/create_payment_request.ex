defmodule ExBank.Payments.CreatePaymentRequest do
  defstruct [:account_id, :amount, :receiver_account_number, :receiver_sort_code, :receiver_account_name]
  alias ExBank.Payments.CreatePaymentRequest

  @types %{
    account_id: :integer,
    amount: :decimal,
    receiver_account_number: :string,
    receiver_sort_code: :string,
    receiver_account_name: :string
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
