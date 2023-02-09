defmodule ExBank.PaymentsTest do
  use ExBank.DataCase
  use Oban.Testing, repo: ExBank.Repo

  alias ExBank.Payments
  alias ExBank.Payments.{Account, Transaction, CreatePaymentRequest}
  alias ExBank.Payments.Jobs.SendPaymentViaProvider
  alias ExBank.Repo

  import ExBank.Payments.Jobs.SendPaymentViaProvider
  import ExBank.PaymentsFixtures
  import Tesla.Mock

  test "Can send money" do
    # Setup
    %{id: account_id} = account_fixture(%{balance: 50})

    # Execution
    {:ok, created_transaction} =
      Payments.send_money(%CreatePaymentRequest{
        account_id: account_id,
        amount: 30,
        receiver_account_number: "123",
        receiver_sort_code: "123123",
        receiver_account_name: "Bob"
      })

    # Expected values
    updated_account = Repo.get!(Account, account_id)
    [queued_payment_job] = all_enqueued()

    expected_transaction_amount = Decimal.new(30)
    expected_payment_job_id = queued_payment_job.id
    expected_payment_idempotency_key = created_transaction.payment_idempotency_key

    # Verify the transaction has been created correctly
    assert %{
             amount: ^expected_transaction_amount,
             receiver_account_name: "Bob",
             receiver_account_number: "123",
             receiver_sort_code: "123123",
             state: :pending,
             account_id: ^account_id,
             payment_error_message: nil,
             payment_job_id: ^expected_payment_job_id
           } = created_transaction

    assert created_transaction.payment_idempotency_key != nil
    assert created_transaction.inserted_at != nil
    assert created_transaction.updated_at != nil

    # Ensure the balance on the account has been updated
    assert updated_account.balance == Decimal.new(20)

    # Verify the oban job is correct before execution
    assert %{
             "account_id" => ^account_id,
             "amount" => 30,
             "payment_idempotency_key" => ^expected_payment_idempotency_key,
             "receiver_account_name" => "Bob",
             "receiver_account_number" => "123",
             "receiver_sort_code" => "123123"
           } = queued_payment_job.args

    # Execute the payment job
    expected_transaction_get_url =
      "https://payment_provider/transaction/#{expected_payment_idempotency_key}"

    mock(fn
      %{method: :post, url: "https://payment_provider/transaction", body: body} ->
        # Verify that the provider receives the correct payload
        assert %{
                 "account_id" => ^account_id,
                 "amount" => 30,
                 "idempotency_key" => ^expected_payment_idempotency_key,
                 "receiver_account_name" => "Bob",
                 "receiver_account_number" => "123",
                 "receiver_sort_code" => "123123",
                 "sender_account_name" => "some account_name",
                 "sender_account_number" => "123456789",
                 "sender_sort_code" => "600666"
               } = Jason.decode!(body)

        %Tesla.Env{status: 200}

      %{method: :get, url: ^expected_transaction_get_url} ->
        # Do a 404 to ensure a transaction is created
        %Tesla.Env{status: 404}
    end)

    assert :ok = perform_job(SendPaymentViaProvider, queued_payment_job.args)

    updated_transaction = Repo.get!(Transaction, created_transaction.id)

    # Verify that transaction has been set as suceeded
    assert %{
             state: :succeeded
           } = updated_transaction
  end

  test "Checks if provider already processed transactions (in cases of mid job crashes)" do
    # Setup
    %{id: account_id} = account_fixture(%{balance: 50})

    # Execution
    {:ok, created_transaction} =
      Payments.send_money(%CreatePaymentRequest{
        account_id: account_id,
        amount: 30,
        receiver_account_number: "123",
        receiver_sort_code: "123123",
        receiver_account_name: "Bob"
      })

    [queued_payment_job] = all_enqueued()

    expected_transaction_get_url =
      "https://payment_provider/transaction/#{created_transaction.payment_idempotency_key}"

    # By not mocking the post, we ensure that the payment provider isn't receiving a post
    # because if it did, it would return failure with no mock set.
    mock(fn
      %{method: :get, url: ^expected_transaction_get_url} ->
        # Do a 404 to ensure a transaction is created
        %Tesla.Env{status: 200}
    end)

    assert :ok = perform_job(SendPaymentViaProvider, queued_payment_job.args)

    updated_transaction = Repo.get!(Transaction, created_transaction.id)

    # Verify that transaction has been set as suceeded
    assert %{
             state: :succeeded
           } = updated_transaction
  end

  test "Not enough funds doesnt produce transaction" do
    # Setup
    %{id: account_id} = account_fixture(%{balance: 50})

    # Execution
    {:error, ["balance_must_be_positive"]} =
      Payments.send_money(%CreatePaymentRequest{
        account_id: account_id,
        amount: 60,
        receiver_account_number: "123",
        receiver_sort_code: "123123",
        receiver_account_name: "Bob"
      })

    # Assert nothing committed in transaction.
    assert [] = all_enqueued()
    updated_account = Repo.get!(Account, account_id)
    assert updated_account.balance == Decimal.new(50)
    assert [] = Repo.all(Transaction)
  end

  test "Bad request from payment provider results in compensation transaction" do
    # Setup
    %{id: account_id} = account_fixture(%{balance: 50})

    # Execution
    {:ok, created_transaction} =
      Payments.send_money(%CreatePaymentRequest{
        account_id: account_id,
        amount: 30,
        receiver_account_number: "123",
        receiver_sort_code: "123123",
        receiver_account_name: "Bob"
      })

    [queued_payment_job] = all_enqueued()

    expected_transaction_get_url =
      "https://payment_provider/transaction/#{created_transaction.payment_idempotency_key}"

    # By not mocking the post, we ensure that the payment provider isn't receiving a post
    # because if it did, it would return failure with no mock set.
    mock(fn
      %{method: :post, url: "https://payment_provider/transaction"} ->
        %Tesla.Env{status: 400, body: "This transaction cannot happen!"}

      %{method: :get, url: ^expected_transaction_get_url} ->
        # Do a 404 to ensure a transaction is created
        %Tesla.Env{status: 404}
    end)

    assert :ok = perform_job(SendPaymentViaProvider, queued_payment_job.args)

    updated_transaction = Repo.get!(Transaction, created_transaction.id)
    updated_account = Repo.get!(Account, account_id)

    # Verify that transaction has been set as suceeded
    assert %{
             state: :failed,
             payment_error_message: "This transaction cannot happen!"
           } = updated_transaction

    assert updated_account.balance == Decimal.new(50)
  end
end
