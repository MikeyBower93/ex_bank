defmodule ExBank.Payments.Jobs.PaymentProviderClient do
  def get_transaction(idempotency_key) do
    {:ok, response} = Tesla.get(client(), "transaction/#{idempotency_key}")
    response
  end

  def create_transaction(payload) do
    {:ok, response} = Tesla.post(client(), "transaction", payload)
    response
  end

  defp client() do
    api_key = Application.get_env(:ex_bank, :payment_provider_api_key)

    middleware = [
      {Tesla.Middleware.BaseUrl, "https://payment_provider"},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers, [{"api_key", api_key}]}
    ]

    Tesla.client(middleware)
  end
end
