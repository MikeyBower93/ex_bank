defmodule ExBank.Payments do
  @moduledoc """
  Domain logic for payments based activity.
  """

  import Ecto.Query, warn: false
  alias ExBank.Repo
  alias ExBank.Payments.{Account, Transaction, CreatePaymentRequest}
  alias ExBank.Payments.Jobs.SendPaymentViaProvider

  @doc """
  Get the account by id.

  Returns %Account{}

  ## Examples
  iex> ExBank.Payments.get_account(1)
  %Account{}
  """
  def get_account(account_id) when is_integer(account_id) do
    Repo.get!(Account, account_id)
  end

  @doc """
  Marks a transaction as completed (state: succeeded) by idempotency_key

  Returns {:ok %Transaction{}} when successful
  Returns {:error %Transaction{}} when failure

  ## Examples
  iex> ExBank.Payments.complete_transaction("12345-12345")
  {:ok, %Transaction{}}
  """
  def complete_transaction(idempotency_key) when is_binary(idempotency_key) do
    Transaction
    |> Repo.get_by!(payment_idempotency_key: idempotency_key)
    |> Transaction.completion_changeset()
    |> Repo.update()
  end

  @doc """
  Reverses a transaction by marking the state: failed and puts money back in the wallet by idempotency_key, account_id and the error received.

  Returns {:ok %Transaction{}} when successful
  Returns {:error %Transaction{}} when failure

  ## Examples
  iex> ExBank.Payments.reverse_transaction("12345-12345", 1, "cannot send the money")
  {:ok, %Transaction{}}
  """
  def reverse_transaction(idempotency_key, account_id, error)
      when is_binary(idempotency_key) and is_binary(error) do
    transaction = Repo.get_by!(Transaction, payment_idempotency_key: idempotency_key)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:transaction_update, Transaction.failure_changeset(transaction, error))
    |> Ecto.Multi.update_all(
      :update_balance,
      from(a in Account, where: a.id == ^account_id),
      inc: [balance: transaction.amount]
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{transaction_update: updated_transaction}} -> {:ok, updated_transaction}
      {:error, _step, %Ecto.Changeset{errors: errors}, _rest} -> {:error, errors}
      otherwise -> otherwise
    end
  end

  @doc """
  Sends payment from an `account_id` to another bank account to a sort code, account number and account name.

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
