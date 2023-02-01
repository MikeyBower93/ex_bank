defmodule ExBankWeb.PageController do
  use ExBankWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
