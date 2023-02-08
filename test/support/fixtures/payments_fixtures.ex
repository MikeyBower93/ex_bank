defmodule ExBank.PaymentsFixtures do
  alias ExBank.Payments.Account
  alias ExBank.Repo

  def account_fixture(attrs \\ %{}) do
    params =
      Enum.into(attrs, %{
        balance: "120.5",
        customer_name: "some customer_name",
        account_name: "some account_name",
        account_number: "123456789",
        account_sort_code: "600666"
      })

    {:ok, account} =
      Account.changeset(
        %Account{},
        params
      )
      |> Repo.insert()

    account
  end
end
