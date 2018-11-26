defmodule Webbkoll.MoreSecureHeaders do
  import Plug.Conn

  def init(default), do: default

  def call(conn, _default) do
    conn
    |> put_resp_header("Content-Security-Policy", "default-src 'self'")
    |> put_resp_header("Referrer-Policy", "no-referrer")
  end
end
