defmodule MooMarketsWeb.CredentialsLive.FormComponent do
  use MooMarketsWeb, :live_component

  alias MooMarkets.Auth
  alias MooMarkets.Auth.JQuantsApi

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>J-Quants API の認証情報を管理します</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="credentials-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:email]} type="email" label="メールアドレス" required />
        <.input field={@form[:password]} type="password" label="パスワード" required />
        <:actions>
          <.button phx-disable-with="保存中...">保存</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{credentials: credentials} = assigns, socket) do
    changeset = Auth.change_credentials(credentials)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"credentials" => credentials_params}, socket) do
    params_to_validate = Map.take(credentials_params, ["email", "password"])

    changeset =
      socket.assigns.credentials
      |> Auth.change_credentials(params_to_validate)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"credentials" => credentials_params}, socket) do
    params_to_save = Map.take(credentials_params, ["email", "password"])
    save_credentials(socket, socket.assigns.action, params_to_save)
  end

  defp save_credentials(socket, :edit, credentials_params) do
    with {:ok, refresh_result} <- JQuantsApi.get_refresh_token(credentials_params["email"], credentials_params["password"]),
         {:ok, id_result} <- JQuantsApi.get_id_token(refresh_result.refresh_token),
         {:ok, credentials} <- Auth.update_credentials(socket.assigns.credentials, credentials_params),
         {:ok, credentials} <- Auth.update_credentials_tokens(credentials, Map.merge(refresh_result, id_result)) do
      notify_parent({:saved, credentials})

      {:noreply,
       socket
       |> put_flash(:info, "認証情報を更新しました")
       |> push_patch(to: socket.assigns.patch)}
    else
      {:error, %{status: status, body: body}} ->
        {:noreply,
         socket
         |> put_flash(:error, "認証に失敗しました: #{status} #{inspect(body)}")}
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "認証に失敗しました: #{inspect(reason)}")}
    end
  end

  defp save_credentials(socket, :new, credentials_params) do
    with {:ok, refresh_result} <- JQuantsApi.get_refresh_token(credentials_params["email"], credentials_params["password"]),
         {:ok, id_result} <- JQuantsApi.get_id_token(refresh_result.refresh_token),
         {:ok, credentials} <- Auth.create_credentials(credentials_params),
         {:ok, credentials} <- Auth.update_credentials_tokens(credentials, Map.merge(refresh_result, id_result)) do
      notify_parent({:saved, credentials})

      {:noreply,
       socket
       |> put_flash(:info, "認証情報を登録しました")
       |> push_patch(to: socket.assigns.patch)}
    else
      {:error, %{status: status, body: body}} ->
        {:noreply,
         socket
         |> put_flash(:error, "認証に失敗しました: #{status} #{inspect(body)}")}
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "認証に失敗しました: #{inspect(reason)}")}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
