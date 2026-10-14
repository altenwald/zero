defmodule ZeroWeb.Request do
  @moduledoc """
  Request is a toolset for all of the functions that are useful
  from the point of view of the request.
  """

  @doc """
  Based on a connection, it's getting the IP address and translating it to
  string or search for the `x-forwarded-for` header in case of the loopback
  IP is detected (a proxy running in the same machine).
  """
  @spec remote_ip(Plug.Conn.t()) :: String.t()
  def remote_ip(conn) do
    case Plug.Conn.get_peer_data(conn).address do
      {127, 0, 0, 1} ->
        case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
          [remote_ip | _] -> remote_ip
          [] -> "127.0.0.1"
        end

      remote_ip ->
        to_string(:inet.ntoa(remote_ip))
    end
  end
end
