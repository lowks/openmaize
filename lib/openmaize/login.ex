defmodule Openmaize.Login do
  @moduledoc """
  Module to handle password authentication and the generation
  of tokens.
  """

  import Plug.Conn
  import Ecto.Query
  import Openmaize.Errors
  alias Openmaize.Config
  alias Openmaize.Token

  @token_info Config.token_info

  @doc """
  Function to handle user login for apis.

  A token will be sent to the user if there is no error. If there is an error,
  an error message will be sent.
  """
  def call(%{params: params} = conn, {false, _}) do
    %{"name" => name, "password" => password} = Map.take(params, ["name", "password"])
    case login_user(name, password) do
      false -> send_error(conn, 401, "Invalid credentials")
      user -> add_token(user, conn, :session)
    end
  end

  @doc """
  Function to handle user login for browser.

  If there is no error, a token will be created and sent to the user so that
  the user can make further requests without logging in again. The user will
  then be redirected to the main page / user page.

  If there is an error, the user will be redirected to the login page.
  """
  def call(%{params: params} = conn, _opts) do
    %{"name" => name, "password" => password} = Map.take(params["user"], ["name", "password"])
    case login_user(name, password) do
      false -> handle_error(conn, "Invalid credentials")
      user -> add_token(user, conn, Config.storage_method)
    end
  end

  defp login_user(name, password) do
    from(user in Config.user_model,
    where: user.name == ^name,
    select: user)
    |> Config.repo.one
    |> check_user(password)
  end

  defp check_user(nil, _), do: Config.get_crypto_mod.dummy_checkpw
  defp check_user(user, password) do
    Config.get_crypto_mod.checkpw(password, user.password_hash) and user
  end

  defp add_token(user, conn, storage) when storage == :cookie do
    role = Map.get(user, :role)
    {:ok, token} = generate_token(user)
    put_resp_cookie(conn, "access_token", token, [http_only: true])
    |> handle_info(role, "You have been logged in")
  end
  defp add_token(user, conn, _storage) do
    {:ok, token} = generate_token(user)
    token_string = ~s({"access_token": #{token}})
    send_resp(conn, 200, token_string) |> halt
  end

  defp generate_token(user) do
    Map.take(user, [:id, :name, :role] ++ @token_info)
    |> Map.merge(%{exp: token_expiry_secs})
    |> Token.encode
  end

  defp token_expiry_secs do
    current_time + Config.token_validity
  end 

  defp current_time do
    {mega, secs, _} = :os.timestamp
    mega * 1000000 + secs
  end
end
