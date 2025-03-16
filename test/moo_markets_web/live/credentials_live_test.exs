defmodule MooMarketsWeb.CredentialsLiveTest do
  use MooMarketsWeb.ConnCase

  import Phoenix.LiveViewTest
  import MooMarkets.AuthFixtures

  @create_attrs %{password: "some password", email: "some email", refresh_token: "some refresh_token", id_token: "some id_token", refresh_token_expires_at: "2025-03-15T16:28:00Z", id_token_expires_at: "2025-03-15T16:28:00Z"}
  @update_attrs %{password: "some updated password", email: "some updated email", refresh_token: "some updated refresh_token", id_token: "some updated id_token", refresh_token_expires_at: "2025-03-16T16:28:00Z", id_token_expires_at: "2025-03-16T16:28:00Z"}
  @invalid_attrs %{password: nil, email: nil, refresh_token: nil, id_token: nil, refresh_token_expires_at: nil, id_token_expires_at: nil}

  defp create_credentials(_) do
    credentials = credentials_fixture()
    %{credentials: credentials}
  end

  describe "Index" do
    setup [:create_credentials]

    test "lists all credentials", %{conn: conn, credentials: credentials} do
      {:ok, _index_live, html} = live(conn, ~p"/credentials")

      assert html =~ "Listing Credentials"
      assert html =~ credentials.password
    end

    test "saves new credentials", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/credentials")

      assert index_live |> element("a", "New Credentials") |> render_click() =~
               "New Credentials"

      assert_patch(index_live, ~p"/credentials/new")

      assert index_live
             |> form("#credentials-form", credentials: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#credentials-form", credentials: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/credentials")

      html = render(index_live)
      assert html =~ "Credentials created successfully"
      assert html =~ "some password"
    end

    test "updates credentials in listing", %{conn: conn, credentials: credentials} do
      {:ok, index_live, _html} = live(conn, ~p"/credentials")

      assert index_live |> element("#credentials-#{credentials.id} a", "Edit") |> render_click() =~
               "Edit Credentials"

      assert_patch(index_live, ~p"/credentials/#{credentials}/edit")

      assert index_live
             |> form("#credentials-form", credentials: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#credentials-form", credentials: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/credentials")

      html = render(index_live)
      assert html =~ "Credentials updated successfully"
      assert html =~ "some updated password"
    end

    test "deletes credentials in listing", %{conn: conn, credentials: credentials} do
      {:ok, index_live, _html} = live(conn, ~p"/credentials")

      assert index_live |> element("#credentials-#{credentials.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#credentials-#{credentials.id}")
    end
  end

  describe "Show" do
    setup [:create_credentials]

    test "displays credentials", %{conn: conn, credentials: credentials} do
      {:ok, _show_live, html} = live(conn, ~p"/credentials/#{credentials}")

      assert html =~ "Show Credentials"
      assert html =~ credentials.password
    end

    test "updates credentials within modal", %{conn: conn, credentials: credentials} do
      {:ok, show_live, _html} = live(conn, ~p"/credentials/#{credentials}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Credentials"

      assert_patch(show_live, ~p"/credentials/#{credentials}/show/edit")

      assert show_live
             |> form("#credentials-form", credentials: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#credentials-form", credentials: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/credentials/#{credentials}")

      html = render(show_live)
      assert html =~ "Credentials updated successfully"
      assert html =~ "some updated password"
    end
  end
end
