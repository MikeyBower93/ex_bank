defmodule ExBank.Payments.Jobs.SendPaymentViaProvider do
  use Oban.Worker

  alias ExBank.Payments
  alias ExBank.Payments.Clients.PaymentProviderClient

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: args
      }) do
    # Check to see if the transaction already exists
    # in cases of this job being cancelled due to a container crash
    # half through the job
    args = Map.new(args, fn {k, v} -> {String.to_existing_atom(k), v} end)

    args.payment_idempotency_key
    |> PaymentProviderClient.get_transaction()
    |> maybe_send_money(args)
  end

  # Doesn't exist, so lets create payment with the provider
  defp maybe_send_money(%{status: 404}, %{
         amount: amount,
         account_id: account_id,
         receiver_account_number: receiver_account_number,
         receiver_sort_code: receiver_sort_code,
         receiver_account_name: receiver_account_name,
         payment_idempotency_key: payment_idempotency_key
       }) do
    %{
      account_name: sender_account_name,
      account_number: sender_account_number,
      account_sort_code: sender_sort_code
    } = Payments.get_account(account_id)

    %{
      amount: amount,
      account_id: account_id,
      idempotency_key: payment_idempotency_key,
      sender_account_number: sender_account_number,
      sender_sort_code: sender_sort_code,
      sender_account_name: sender_account_name,
      receiver_account_number: receiver_account_number,
      receiver_sort_code: receiver_sort_code,
      receiver_account_name: receiver_account_name
    }
    |> PaymentProviderClient.create_transaction()
    |> case do
      # Success, we can complete the transaction
      %{status: status} when status in [200, 201] ->
        {:ok, _} = Payments.complete_transaction(payment_idempotency_key)
        :ok

      # Bad request we need to fail and cancel the transaction.
      %{status: status, body: error} when status in [400] ->
        {:ok, _} = Payments.reverse_transaction(payment_idempotency_key, account_id, error)
        :ok

      # Unexpected case, oban to retry with error message for logging.
      %{body: error} ->
        {:error, error}
    end
  end

  # Transaction already exists, lets just ensure its marked as completed.
  defp maybe_send_money(%{status: 200}, %{
         payment_idempotency_key: payment_idempotency_key
       }) do
    {:ok, _} = Payments.complete_transaction(payment_idempotency_key)
    :ok
  end

  # Unexpected case, oban to retry with error message for logging.
  defp maybe_send_money(%{body: error}, _data) do
    {:error, error}
  end
end
