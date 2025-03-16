defmodule MooMarketsWeb.CredentialsLive.Index do
  use MooMarketsWeb, :live_view

  alias MooMarkets.Auth
  alias MooMarkets.Auth.Credentials

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :credentials_collection, Auth.list_credentials())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "認証情報の編集")
    |> assign(:credentials, Auth.get_credentials(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "新規認証情報の登録")
    |> assign(:credentials, %Credentials{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "認証情報一覧")
    |> assign(:credentials, nil)
  end

  @impl true
  def handle_info({MooMarketsWeb.CredentialsLive.FormComponent, {:saved, credentials}}, socket) do
    {:noreply, stream_insert(socket, :credentials_collection, credentials)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    credentials = Auth.get_credentials(id)
    {:ok, _} = Auth.delete_credentials(credentials)

    {:noreply, stream_delete(socket, :credentials_collection, credentials)}
  end
end
