defmodule ZeroWeb.Request do
  @moduledoc """
  Request is a toolset for all of the functions that are useful
  from the point of view of the request.
  """

  @doc """
  Based on a request (cowboy), it's getting the IP address and translating
  it to string or search for different fields in case of the loopback IP is
  detected.
  """
  def remote_ip(req) do
    case :cowboy_req.peer(req) do
      {{127, 0, 0, 1}, _port_number} ->
        case :cowboy_req.header("x-forwarded-for", req) do
          :undefined -> "127.0.0.1"
          remote_ip -> remote_ip
        end

      {remote_ip, _port_number} ->
        to_string(:inet.ntoa(remote_ip))
    end
  end
end
