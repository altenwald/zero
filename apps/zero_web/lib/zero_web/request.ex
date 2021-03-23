defmodule ZeroWeb.Request do
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
