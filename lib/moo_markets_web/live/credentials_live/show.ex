defmodule MooMarketsWeb.CredentialsLive.Show do
  use MooMarketsWeb, :live_view

  alias MooMarkets.Auth

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    case Auth.get_credentials(id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "認証情報が見つかりません")
         |> push_navigate(to: ~p"/credentials")}

      credentials ->
        {:noreply,
         socket
         |> assign(:page_title, "認証情報の詳細")
         |> assign(:credentials, credentials)}
    end
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, push_patch(socket, to: ~p"/credentials/#{socket.assigns.credentials}")}
  end
end
