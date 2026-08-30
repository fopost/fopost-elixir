defmodule FoPost.Labels do
  @moduledoc """
  Labels — the campaign tags posts are grouped and reported by.
  """

  alias FoPost.Client
  alias FoPost.Label
  alias FoPost.Message
  alias FoPost.Model
  alias FoPost.Result

  @doc """
  The labels the key can reach, optionally narrowed with `:workspace_id`.
  """
  @spec list(Client.t(), keyword()) :: {:ok, [Label.t()]} | {:error, FoPost.Error.t()}
  def list(client, opts \\ []) do
    params = Model.take_params(opts, [:workspace_id])

    with {:ok, data} <- Client.request(client, :get, "/labels", params: params) do
      {:ok, Model.list(Label, data)}
    end
  end

  @doc """
  One label.
  """
  @spec get(Client.t(), String.t()) :: {:ok, Label.t()} | {:error, FoPost.Error.t()}
  def get(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id)) do
      {:ok, Label.from_map(data)}
    end
  end

  @doc """
  Adds a label to a workspace.

  Required: `:workspace_id`, `:name`, `:color`. `:color` is a hex value, e.g. `"#2563eb"`.
  """
  @spec create(Client.t(), keyword()) :: {:ok, Label.t()} | {:error, FoPost.Error.t()}
  def create(client, opts) do
    body = Model.take_body(opts, [:workspace_id, :name, :color])

    with {:ok, data} <- Client.request(client, :post, "/labels", json: body) do
      {:ok, Label.from_map(data)}
    end
  end

  @doc """
  Renames or recolors a label. Both `:name` and `:color` are required.
  """
  @spec update(Client.t(), String.t(), keyword()) :: {:ok, Label.t()} | {:error, FoPost.Error.t()}
  def update(client, id, opts) do
    body = Model.take_body(opts, [:name, :color])

    with {:ok, data} <- Client.request(client, :put, path(id), json: body) do
      {:ok, Label.from_map(data)}
    end
  end

  @doc """
  Removes a label and unlinks it from every post carrying it.
  """
  @spec delete(Client.t(), String.t()) :: {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def delete(client, id) do
    with {:ok, data} <- Client.request(client, :delete, path(id)) do
      {:ok, Message.from_map(data)}
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

  defp path(id), do: "/labels/" <> URI.encode(to_string(id), &URI.char_unreserved?/1)
end
