defmodule ExBank.PaymentsTest do
  use ExBank.DataCase
  use Oban.Testing, repo: ExBank.Repo

  alias ExBank.Payments
  alias ExBank.Payments.Account
  alias ExBank.Payments.Jobs.SendPaymentViaProvider
  alias ExBank.Repo
  import ExBank.PaymentsFixtures

  test "Can send money" do
    account = account_fixture(%{balance: 50})

    {:ok, transaction} = Payments.send_money(account.id, 30, "123", "123", "Bob")

    assert transaction.amount == Decimal.new(30)
    assert Repo.get!(Account, account.id).balance == Decimal.new(20)
    assert worker: SendPaymentViaProvider,
           args: %{
             "account_id" => 55,
             "amount" => 10,
             "to_account_number" => "123",
             "to_name" => "Bob",
             "to_sort_code" => "123"
           }
  end
end
