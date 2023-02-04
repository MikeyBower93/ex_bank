defmodule ExBank.Payments do
  @moduledoc """
  Domain logic for payments based activity.
  """

  import Ecto.Query, warn: false
  alias ExBank.Repo
  alias ExBank.Payments.{Account, Transaction, CreatePaymentRequest}
  alias ExBank.Payments.Jobs.SendPaymentViaProvider

  @doc """
  Sends payment from an `account_id` to another bank account via a sort code, account number and name.

  Returns `{:ok, %Transaction{}}` where the transaction is the new created transaction.
  Returns `{:error, errors}` where the errors is a list of errors.

  ## Examples

      iex> ExBank.Payments.send_money(%ExBank.Payments.CreatePaymentRequest{
          account_id: 1,
          amount: 75,
          receiver_sort_code: "60-00-00",
          receiver_account_number: "1234567",
          receiver_account_name: "Bob Robert"
        })
      {:ok, %Transaction{...}}

      iex> ExBank.Payments.send_money(%ExBank.Payments.CreatePaymentRequest{
          account_id: 1,
          amount: 75,
          receiver_sort_code: "60-00-00",
          receiver_account_number: "1234567",
          receiver_account_name: ""
        })
      {:ok, errors}

  """
  def send_money(%CreatePaymentRequest{} = create_payment_request) do
    with {:valid, verified_create_payment_request} <-
           CreatePaymentRequest.verify(create_payment_request),
         response <- do_send_money(verified_create_payment_request) do
      response
    else
      error -> error
    end
  end

  defp do_send_money(%CreatePaymentRequest{} = create_payment_request) do
    payment_idempotency_key = Ecto.UUID.generate()

    Ecto.Multi.new()
    |> prepare_update_balance_step(create_payment_request)
    |> prepare_payment_job_step(payment_idempotency_key, create_payment_request)
    |> prepare_create_transaction_step(payment_idempotency_key, create_payment_request)
    |> execute_masked_transaction()
    |> case do
      {:ok, %{create_transaction: new_transaction}} -> {:ok, new_transaction}
      {:error, _step, %Ecto.Changeset{errors: errors}, _rest} -> {:error, errors}
      otherwise -> otherwise
    end
  end

  def execute_masked_transaction(multi) do
    try do
      Repo.transaction(multi)
    catch
      _kind,
      %Postgrex.Error{
        postgres: %{
          constraint: constraint
        }
      } ->
        {:error, [constraint]}
    end
  end

  defp prepare_update_balance_step(
         multi,
         %CreatePaymentRequest{
           account_id: account_id,
           amount: amount
         }
       ) do
    Ecto.Multi.update_all(
      multi,
      :update_balance,
      from(a in Account, where: a.id == ^account_id),
      inc: [balance: -amount]
    )
  end

  defp prepare_payment_job_step(
         multi,
         payment_idempotency_key,
         %CreatePaymentRequest{
           account_id: account_id,
           amount: amount,
           receiver_account_number: receiver_account_number,
           receiver_sort_code: receiver_sort_code,
           receiver_account_name: receiver_account_name
         }
       ) do
    oban_job_params = %{
      amount: amount,
      account_id: account_id,
      receiver_account_number: receiver_account_number,
      receiver_sort_code: receiver_sort_code,
      receiver_account_name: receiver_account_name,
      payment_idempotency_key: payment_idempotency_key
    }

    Oban.insert(
      multi,
      :send_payment_via_provider,
      SendPaymentViaProvider.new(oban_job_params)
    )
  end

  defp prepare_create_transaction_step(
         multi,
         payment_idempotency_key,
         %CreatePaymentRequest{
           account_id: account_id,
           amount: amount,
           receiver_account_number: receiver_account_number,
           receiver_sort_code: receiver_sort_code,
           receiver_account_name: receiver_account_name
         }
       ) do
    Ecto.Multi.run(
      multi,
      :create_transaction,
      fn repo, %{send_payment_via_provider: %{id: payment_job_id}} ->
        new_transaction_params = %{
          amount: amount,
          receiver_account_name: receiver_account_name,
          receiver_account_number: receiver_account_number,
          receiver_sort_code: receiver_sort_code,
          state: :pending,
          account_id: account_id,
          payment_job_id: payment_job_id,
          payment_idempotency_key: payment_idempotency_key
        }

        %Transaction{}
        |> Transaction.changeset(new_transaction_params)
        |> repo.insert()
      end
    )
  end
end
