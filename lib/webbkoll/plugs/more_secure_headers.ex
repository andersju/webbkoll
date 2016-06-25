defmodule Webbkoll.MoreSecureHeaders do
  import Plug.Conn

  def init(default), do: default

  def call(conn, _default) do
    conn
    |> put_resp_header("content-security-policy", "default-src 'self'")
    |> put_resp_header("x-content-security-policy", "default-src 'self'")
  end
end
