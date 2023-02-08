defmodule ExBank.PaymentsTest do
  use ExBank.DataCase
  use Oban.Testing, repo: ExBank.Repo

  alias ExBank.Payments
  alias ExBank.Payments.{Account, CreatePaymentRequest}
  alias ExBank.Payments.Jobs.SendPaymentViaProvider
  alias ExBank.Repo

  import ExBank.PaymentsFixtures
  import Tesla.Mock

  setup do
    mock(fn
      %{method: :post, url: "https://payment_provider/transaction"} ->
        %Tesla.Env{status: 200}

      %{method: :get} ->
        %Tesla.Env{status: 200}
    end)

    :ok
  end

  test "Can send money" do
    account = account_fixture(%{balance: 50})

    {:ok, transaction} =
      Payments.send_money(%CreatePaymentRequest{
        account_id: account.id,
        amount: 30,
        receiver_account_number: "123",
        receiver_sort_code: "123123",
        receiver_account_name: "Bob"
      })

    assert transaction.amount == Decimal.new(30)
    assert Repo.get!(Account, account.id).balance == Decimal.new(20)

    assert worker: SendPaymentViaProvider,
           args: %{
             "account_id" => 55,
             "amount" => 10,
             "receiver_account_number" => "123",
             "receiver_account_name" => "Bob",
             "receiver_sort_code" => "123"
           }
  end
end
