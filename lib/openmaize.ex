defmodule Openmaize do
  @moduledoc """
  This module handles the initial call to Openmaize and then calls the
  relevant module for handling authentication, logging in or logging
  out.

  If the path is for the login page and the method is "POST", the
  connection is redirected to the Openmaize.Login module. If the
  method is "GET", the user is allowed to go to the login page.

  If the path is for the logout page, the connection is redirected
  to the Openmaize.Logout module, which handles the logout and redirects
  the user to the home page.

  For any other path, including unprotected paths, the connection is
  redirected to the Openmaize.Authenticate module, which handles
  authentication.

  ## Phoenix integration

  The `current_user` variable is set for every path. This means that
  you can access `@current_user` in any of your templates. If nobody
  is logged in, `current_user` is set to nil.

  """

  import Plug.Conn
  import Openmaize.Errors
  alias Openmaize.Authenticate
  alias Openmaize.Config
  alias Openmaize.Login
  alias Openmaize.Logout

  @behaviour Plug

  def init(opts), do: opts

  @doc """
  Function to check the token provided. If there is no token, or if the
  token is invalid, the user is redirected to the login page.

  If the path is for the login or logout page, the user is redirected
  to that page straight away.

  ## Options

  There are two options available: `redirects` and `check`.

  `redirects` is set to true by default, which is probably what you need
  for an application in the browser. For an api, though, or a Single Page
  Application, you will probably just want responses without redirects.

  `check` is for a function to perform extra checks before authenticating
  the user. This option is available so that the authentication of users
  can be more easily customized. There are some examples of this kind of
  function in the Openmaize.IdCheck module.

  ## Examples

  Call openmaize with no options:

      plug Openmaize

  Call openmaize for an api with a further id check:

      import Openmaize.IdCheck

      plug Openmaize, redirects: false, check: &id_noedit/4

  """
  def call(%{path_info: path_info} = conn, opts) do
    opts = {Keyword.get(opts, :redirects), Keyword.get(opts, :check)}
    case Enum.at(path_info, -1) do
      "login" -> handle_login(conn, opts)
      "logout" -> handle_logout(conn, opts)
      _ -> handle_auth(conn, opts)
    end
  end

  defp handle_login(%{method: "POST"} = conn, opts), do: Login.call(conn, opts)
  defp handle_login(conn, _opts), do: assign(conn, :current_user, nil)

  defp handle_logout(conn, opts), do: assign(conn, :current_user, nil) |> Logout.call(opts)

  defp handle_auth(conn, {false, _check} = opts) do
    Authenticate.call(conn, opts) |> auth(conn, opts)
  end
  defp handle_auth(conn, opts) do
    Authenticate.call(conn, [storage: Config.storage_method]) |> auth(conn, opts)
  end

  defp auth({:ok, data}, conn, _), do: assign(conn, :current_user, data)
  defp auth({:ok, data, _, _}, conn, {_, nil}), do: assign(conn, :current_user, data)
  defp auth({:ok, data, path, match}, conn, {_, func}) do
    func.(conn, data, path, match) |> auth(conn, {nil, nil})
  end
  defp auth({:error, message}, conn, {false, _}), do: send_error(conn, 401, message)
  defp auth({:error, message}, conn, _), do: handle_error(conn, message)
  defp auth({:error, _, message}, conn, {false, _}), do: send_error(conn, 403, message)
  defp auth({:error, role, message}, conn, _), do: handle_error(conn, role, message)

end
