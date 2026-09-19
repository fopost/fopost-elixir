defmodule FoPost.AccountGroups do
  @moduledoc """
  Account groups — named sets of accounts a post can target with `:account_group_id`.
  """

  alias FoPost.AccountGroup
  alias FoPost.Client
  alias FoPost.Message
  alias FoPost.Model
  alias FoPost.Result

  @doc """
  The groups the key can reach, optionally narrowed with `:workspace_id`.
  """
  @spec list(Client.t(), keyword()) :: {:ok, [AccountGroup.t()]} | {:error, FoPost.Error.t()}
  def list(client, opts \\ []) do
    params = Model.take_params(opts, [:workspace_id])

    with {:ok, data} <- Client.request(client, :get, "/account-groups", params: params) do
      {:ok, Model.list(AccountGroup, data)}
    end
  end

  @doc """
  One group.
  """
  @spec get(Client.t(), String.t()) :: {:ok, AccountGroup.t()} | {:error, FoPost.Error.t()}
  def get(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id)) do
      {:ok, AccountGroup.from_map(data)}
    end
  end

  @doc """
  Adds a group to a workspace.

  Required: `:workspace_id`, `:name`. Optional: `:account_ids`, the first members.
  """
  @spec create(Client.t(), keyword()) :: {:ok, AccountGroup.t()} | {:error, FoPost.Error.t()}
  def create(client, opts) do
    body = Model.take_body(opts, [:workspace_id, :name, :account_ids])

    with {:ok, data} <- Client.request(client, :post, "/account-groups", json: body) do
      {:ok, AccountGroup.from_map(data)}
    end
  end

  @doc """
  Renames a group. `:name` is required.
  """
  @spec update(Client.t(), String.t(), keyword()) ::
          {:ok, AccountGroup.t()} | {:error, FoPost.Error.t()}
  def update(client, id, opts) do
    body = Model.take_body(opts, [:name])

    with {:ok, data} <- Client.request(client, :patch, path(id), json: body) do
      {:ok, AccountGroup.from_map(data)}
    end
  end

  @doc """
  Removes a group. The accounts in it stay connected.
  """
  @spec delete(Client.t(), String.t()) :: {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def delete(client, id) do
    with {:ok, data} <- Client.request(client, :delete, path(id)) do
      {:ok, Message.from_map(data)}
    end
  end

  @doc """
  Replaces a group's members with `account_ids`.
  """
  @spec set_members(Client.t(), String.t(), [String.t()]) ::
          {:ok, AccountGroup.t()} | {:error, FoPost.Error.t()}
  def set_members(client, id, account_ids) do
    body = %{"account_ids" => account_ids}

    with {:ok, data} <- Client.request(client, :put, path(id) <> "/members", json: body) do
      {:ok, AccountGroup.from_map(data)}
    end
  end

  @doc "Same as `list/2`, but raises `FoPost.Error`."
  def list!(client, opts \\ []), do: Result.unwrap!(list(client, opts))

  @doc "Same as `get/2`, but raises `FoPost.Error`."
  def get!(client, id), do: Result.unwrap!(get(client, id))

  @doc "Same as `create/2`, but raises `FoPost.Error`."
  def create!(client, opts), do: Result.unwrap!(create(client, opts))

  @doc "Same as `update/3`, but raises `FoPost.Error`."
  def update!(client, id, opts), do: Result.unwrap!(update(client, id, opts))

  @doc "Same as `delete/2`, but raises `FoPost.Error`."
  def delete!(client, id), do: Result.unwrap!(delete(client, id))

  @doc "Same as `set_members/3`, but raises `FoPost.Error`."
  def set_members!(client, id, account_ids),
    do: Result.unwrap!(set_members(client, id, account_ids))

  defp path(id), do: "/account-groups/" <> URI.encode(to_string(id), &URI.char_unreserved?/1)
end
