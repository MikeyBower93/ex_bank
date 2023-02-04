defmodule ExBank.Payments do
  import Ecto.Query, warn: false
  alias ExBank.Repo
  alias ExBank.Payments.{Account, Transaction}
  alias ExBank.Payments.Jobs.SendPaymentViaProvider

  def send_money(
        account_id,
        amount,
        to_account_number,
        to_sort_code,
        to_name
      ) do
    try do
      do_send_money(account_id, amount, to_account_number, to_sort_code, to_name)
    catch
      _kind,
      %Postgrex.Error{
        postgres: %{
          constraint: "balance_must_be_positive"
        }
      } ->
        {:error, :not_enough_balance}
    end
  end

  defp do_send_money(
         account_id,
         amount,
         to_account_number,
         to_sort_code,
         to_name
       ) do
    payment_idempotency_key = Ecto.UUID.generate()

    Ecto.Multi.new()
    |> prepare_update_balance_step(account_id, amount)
    |> prepare_payment_job_step(
      account_id,
      amount,
      to_account_number,
      to_sort_code,
      to_name,
      payment_idempotency_key
    )
    |> prepare_create_transaction_step(
      account_id,
      amount,
      to_account_number,
      to_sort_code,
      to_name,
      payment_idempotency_key
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{create_transaction: new_transaction}} -> {:ok, new_transaction}
      {:error, _step, %Ecto.Changeset{errors: errors}, _rest} -> {:error, errors}
      otherwise -> otherwise
    end
  end

  defp prepare_update_balance_step(multi, account_id, amount) do
    Ecto.Multi.update_all(
      multi,
      :update_balance,
      from(a in Account, where: a.id == ^account_id),
      inc: [balance: -amount]
    )
  end

  defp prepare_create_transaction_step(
         multi,
         account_id,
         amount,
         to_account_number,
         to_sort_code,
         to_name,
         payment_idempotency_key
       ) do
    Ecto.Multi.run(
      multi,
      :create_transaction,
      fn repo, %{send_payment_via_provider: %{id: payment_job_id}} ->
        new_transaction_params = %{
          amount: amount,
          error: nil,
          receiver: to_name,
          receiver_account_number: to_account_number,
          receiver_sort_code: to_sort_code,
          state: "PENDING",
          account_id: account_id,
          payment_job_id: payment_job_id,
          payment_idempotency_key: payment_idempotency_key
        }

        %Transaction{}
        |> Transaction.changeset(new_transaction_params)
        |> repo.insert
      end
    )
  end

  defp prepare_payment_job_step(
         multi,
         account_id,
         amount,
         to_account_number,
         to_sort_code,
         to_name,
         payment_idempotency_key
       ) do
    oban_job_params = %{
      amount: amount,
      account_id: account_id,
      to_account_number: to_account_number,
      to_sort_code: to_sort_code,
      to_name: to_name,
      payment_idempotency_key: payment_idempotency_key
    }

    Oban.insert(
      multi,
      :send_payment_via_provider,
      SendPaymentViaProvider.new(oban_job_params)
    )
  end
end
