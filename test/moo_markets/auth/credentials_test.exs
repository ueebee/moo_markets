defmodule MooMarkets.Auth.CredentialsTest do
  use MooMarkets.DataCase

  alias MooMarkets.Auth.Credentials

  describe "credentials" do
    @valid_attrs %{
      email: "test@example.com",
      password: "password123"
    }
    @invalid_attrs %{
      email: nil,
      password: nil
    }

    test "changeset with valid attributes" do
      changeset = Credentials.changeset(%Credentials{}, @valid_attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = Credentials.changeset(%Credentials{}, @invalid_attrs)
      refute changeset.valid?
    end

    test "changeset enforces email format" do
      attrs = Map.put(@valid_attrs, :email, "invalid-email")
      changeset = Credentials.changeset(%Credentials{}, attrs)
      assert "メールアドレスの形式が正しくありません" in errors_on(changeset).email
    end

    test "changeset enforces minimum email length" do
      attrs = Map.put(@valid_attrs, :email, "a@b")
      changeset = Credentials.changeset(%Credentials{}, attrs)
      assert "should be at least 5 character(s)" in errors_on(changeset).email
    end

    test "changeset enforces maximum email length" do
      long_email = String.duplicate("a", 155) <> "@example.com"
      attrs = Map.put(@valid_attrs, :email, long_email)
      changeset = Credentials.changeset(%Credentials{}, attrs)
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "changeset enforces minimum password length" do
      attrs = Map.put(@valid_attrs, :password, "12345")
      changeset = Credentials.changeset(%Credentials{}, attrs)
      assert "should be at least 6 character(s)" in errors_on(changeset).password
    end

    test "changeset enforces maximum password length" do
      long_password = String.duplicate("a", 81)
      attrs = Map.put(@valid_attrs, :password, long_password)
      changeset = Credentials.changeset(%Credentials{}, attrs)
      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "token_changeset with valid attributes" do
      valid_token_attrs = %{
        refresh_token: "refresh_token_123",
        id_token: "id_token_456",
        refresh_token_expires_at: DateTime.utc_now(),
        id_token_expires_at: DateTime.utc_now()
      }
      changeset = Credentials.token_changeset(%Credentials{}, valid_token_attrs)
      assert changeset.valid?
    end

    test "token_changeset with missing attributes" do
      invalid_token_attrs = %{
        refresh_token: "refresh_token_123",
        id_token: nil,
        refresh_token_expires_at: nil,
        id_token_expires_at: nil
      }
      changeset = Credentials.token_changeset(%Credentials{}, invalid_token_attrs)
      refute changeset.valid?
    end

    test "refresh_token_expired? returns true for expired token" do
      credentials = %Credentials{
        refresh_token_expires_at: DateTime.add(DateTime.utc_now(), -1, :hour)
      }
      assert Credentials.refresh_token_expired?(credentials)
    end

    test "refresh_token_expired? returns false for valid token" do
      credentials = %Credentials{
        refresh_token_expires_at: DateTime.add(DateTime.utc_now(), 1, :hour)
      }
      refute Credentials.refresh_token_expired?(credentials)
    end

    test "refresh_token_expired? returns true for nil expiration" do
      credentials = %Credentials{refresh_token_expires_at: nil}
      assert Credentials.refresh_token_expired?(credentials)
    end

    test "id_token_expired? returns true for expired token" do
      credentials = %Credentials{
        id_token_expires_at: DateTime.add(DateTime.utc_now(), -1, :hour)
      }
      assert Credentials.id_token_expired?(credentials)
    end

    test "id_token_expired? returns false for valid token" do
      credentials = %Credentials{
        id_token_expires_at: DateTime.add(DateTime.utc_now(), 1, :hour)
      }
      refute Credentials.id_token_expired?(credentials)
    end

    test "id_token_expired? returns true for nil expiration" do
      credentials = %Credentials{id_token_expires_at: nil}
      assert Credentials.id_token_expired?(credentials)
    end
  end
end
