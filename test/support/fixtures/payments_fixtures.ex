defmodule ExBank.PaymentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ExBank.Payments` context.
  """

  @doc """
  Generate a account.
  """
  def account_fixture(attrs \\ %{}) do
    {:ok, account} =
      attrs
      |> Enum.into(%{
        balance: "120.5",
        customer_name: "some customer_name"
      })
      |> ExBank.Payments.create_account()

    account
  end

  @doc """
  Generate a transaction.
  """
  def transaction_fixture(attrs \\ %{}) do
    {:ok, transaction} =
      attrs
      |> Enum.into(%{
        amount: "120.5",
        error: "some error",
        receiver: "some receiver",
        receiver_account_number: "some receiver_account_number",
        receiver_sort_code: "some receiver_sort_code",
        state: "some state"
      })
      |> ExBank.Payments.create_transaction()

    transaction
  end
end
