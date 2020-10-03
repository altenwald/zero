defmodule ZeroWeb.Request do
  def remote_ip(req) do
    case :cowboy_req.peer(req) do
      {{127, 0, 0, 1}, _} ->
        case :cowboy_req.header("x-forwarded-for", req) do
          {remote_ip, _} -> remote_ip
          _ -> "127.0.0.1"
        end

      {remote_ip, _} ->
        to_string(:inet.ntoa(remote_ip))
    end
  end
end
