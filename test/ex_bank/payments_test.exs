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
end
