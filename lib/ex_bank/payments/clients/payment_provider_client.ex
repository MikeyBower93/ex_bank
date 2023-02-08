defmodule ExBank.Payments.Clients.PaymentProviderClient do
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
      {Tesla.Middleware.Headers, [{"api_key", api_key}]},
      {Tesla.Middleware.Fuse,
       opts: {{:standard, 2, 10_000}, {:reset, 60_000}},
       keep_original_error: true,
       should_melt: fn
         {:ok, %{status: status}} when status in [429] -> true
         {:ok, _} -> false
         {:error, _} -> true
       end,
       mode: :sync}
    ]

    Tesla.client(middleware)
  end
end
