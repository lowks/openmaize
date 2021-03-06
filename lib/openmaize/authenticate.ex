defmodule Openmaize.Authenticate do
  @moduledoc """
  Module to authenticate users using Json Web Tokens.

  ## Json Web Tokens

  Json Web Tokens (JWTs) are an alternative to using cookies to identify,
  and provide information about, users after they have logged in.

  One main advantage of using JWTs is that there is no need to keep a
  session store as the token can be used to contain user information.
  It is important, though, not to keep sensitive information in the
  token as the information is not encrypted -- it is just encoded.

  The JWTs need to be stored somewhere, either in cookies or sessionStorage
  (or localStorage), so that they can be used in subsequent requests. 
  With this module, if you store the token in a cookie, this module handles
  all of the authentication process. If, however, you want to store the
  token in sessionStorage, you will need to add the token to sessionStorage
  with the front-end framework you are using and add the token to the request
  headers for each request.

  """

  import Plug.Conn
  alias Openmaize.Config
  alias Openmaize.Token

  @protected_roles Config.protected
  @protected Map.keys(Config.protected)

  @doc """
  This function is for when the token is stored in a cookie, which is
  the default method.
  """
  def call(conn, [storage: :cookie]) do
    conn = fetch_cookies(conn)
    Map.get(conn.req_cookies, "access_token") |> check_token(conn)
  end

  @doc """
  This function is for when the token is sent in the request header.
  You would use this if you are authenticating an api, or if you are
  storing the token in sessionStorage or localStorage.
  """
  def call(%{req_headers: headers} = conn, _opts) do
    get_token(headers) |> Enum.at(0) |> check_token(conn)
  end

  defp get_token(headers) do
    for {k, v} <- headers, k == "authorization" or k == "access-token", do: v
  end

  defp check_token("Bearer " <> token, conn), do: check_token(token, conn)
  defp check_token(token, conn) when is_binary(token) do
    case Token.decode(token) do
      {:ok, data} -> verify_user(conn, data)
      {:error, message} -> {:error, message}
    end
  end
  defp check_token(_, conn) do
    case check_match(conn) do
      {{0, _}, path} -> {:error, "You have to be logged in to view #{path}"}
      _ -> {:ok, nil}
    end
  end

  defp verify_user(conn, data) do
    case check_match(conn) do
      {{0, match_len}, path} -> verify_role(data, path, :binary.part(path, {0, match_len}))
      _ -> {:ok, data}
    end
  end

  defp verify_role(%{role: role} = data, path, match) do
    if role in Map.get(@protected_roles, match) do
      {:ok, data, path, match}
    else
      {:error, role, "You do not have permission to view #{path}"}
    end
  end

  defp check_match(conn) do
    path = full_path(conn)
    {:binary.match(path, @protected), path}
  end
end
