defmodule ExBank.PaymentsFixtures do
  alias ExBank.Payments.Account
  alias ExBank.Repo

  def account_fixture(attrs \\ %{}) do
    params =
      Enum.into(attrs, %{
        balance: "120.5",
        customer_name: "some customer_name"
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
