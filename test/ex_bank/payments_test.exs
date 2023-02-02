defmodule ExBank.PaymentsTest do
  use ExBank.DataCase

  alias ExBank.Payments

  describe "accounts" do
    alias ExBank.Payments.Account

    import ExBank.PaymentsFixtures

    @invalid_attrs %{balance: nil, customer_name: nil}

    test "list_accounts/0 returns all accounts" do
      account = account_fixture()
      assert Payments.list_accounts() == [account]
    end

    test "get_account!/1 returns the account with given id" do
      account = account_fixture()
      assert Payments.get_account!(account.id) == account
    end

    test "create_account/1 with valid data creates a account" do
      valid_attrs = %{balance: "10", customer_name: "some customer_name"}

      assert {:ok, %Account{} = account} = Payments.create_account(valid_attrs)
      assert account.balance == Decimal.new("10")
      assert account.customer_name == "some customer_name"
    end

    test "create_account/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Payments.create_account(@invalid_attrs)
    end

    test "update_account/2 with valid data updates the account" do
      account = account_fixture()
      update_attrs = %{balance: "456.7", customer_name: "some updated customer_name"}

      assert {:ok, %Account{} = account} = Payments.update_account(account, update_attrs)
      assert account.balance == Decimal.new("456.7")
      assert account.customer_name == "some updated customer_name"
    end

    test "update_account/2 with invalid data returns error changeset" do
      account = account_fixture()
      assert {:error, %Ecto.Changeset{}} = Payments.update_account(account, @invalid_attrs)
      assert account == Payments.get_account!(account.id)
    end

    test "delete_account/1 deletes the account" do
      account = account_fixture()
      assert {:ok, %Account{}} = Payments.delete_account(account)
      assert_raise Ecto.NoResultsError, fn -> Payments.get_account!(account.id) end
    end

    test "change_account/1 returns a account changeset" do
      account = account_fixture()
      assert %Ecto.Changeset{} = Payments.change_account(account)
    end
  end

  describe "transactions" do
    alias ExBank.Payments.Transaction

    import ExBank.PaymentsFixtures

    @invalid_attrs %{amount: nil, error: nil, receiver: nil, receiver_account_number: nil, receiver_sort_code: nil, state: nil}

    test "list_transactions/0 returns all transactions" do
      transaction = transaction_fixture()
      assert Payments.list_transactions() == [transaction]
    end

    test "get_transaction!/1 returns the transaction with given id" do
      transaction = transaction_fixture()
      assert Payments.get_transaction!(transaction.id) == transaction
    end

    test "create_transaction/1 with valid data creates a transaction" do
      valid_attrs = %{amount: "120.5", error: "some error", receiver: "some receiver", receiver_account_number: "some receiver_account_number", receiver_sort_code: "some receiver_sort_code", state: "some state"}

      assert {:ok, %Transaction{} = transaction} = Payments.create_transaction(valid_attrs)
      assert transaction.amount == Decimal.new("120.5")
      assert transaction.error == "some error"
      assert transaction.receiver == "some receiver"
      assert transaction.receiver_account_number == "some receiver_account_number"
      assert transaction.receiver_sort_code == "some receiver_sort_code"
      assert transaction.state == "some state"
    end

    test "create_transaction/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Payments.create_transaction(@invalid_attrs)
    end

    test "update_transaction/2 with valid data updates the transaction" do
      transaction = transaction_fixture()
      update_attrs = %{amount: "456.7", error: "some updated error", receiver: "some updated receiver", receiver_account_number: "some updated receiver_account_number", receiver_sort_code: "some updated receiver_sort_code", state: "some updated state"}

      assert {:ok, %Transaction{} = transaction} = Payments.update_transaction(transaction, update_attrs)
      assert transaction.amount == Decimal.new("456.7")
      assert transaction.error == "some updated error"
      assert transaction.receiver == "some updated receiver"
      assert transaction.receiver_account_number == "some updated receiver_account_number"
      assert transaction.receiver_sort_code == "some updated receiver_sort_code"
      assert transaction.state == "some updated state"
    end

    test "update_transaction/2 with invalid data returns error changeset" do
      transaction = transaction_fixture()
      assert {:error, %Ecto.Changeset{}} = Payments.update_transaction(transaction, @invalid_attrs)
      assert transaction == Payments.get_transaction!(transaction.id)
    end

    test "delete_transaction/1 deletes the transaction" do
      transaction = transaction_fixture()
      assert {:ok, %Transaction{}} = Payments.delete_transaction(transaction)
      assert_raise Ecto.NoResultsError, fn -> Payments.get_transaction!(transaction.id) end
    end

    test "change_transaction/1 returns a transaction changeset" do
      transaction = transaction_fixture()
      assert %Ecto.Changeset{} = Payments.change_transaction(transaction)
    end
  end
end
