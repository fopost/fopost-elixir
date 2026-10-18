defmodule FoPost.Logs do
  @moduledoc """
  Request logs — every call made with the key or from the dashboard, and how it was
  answered. Needs the `workspaces` scope.
  """

  alias FoPost.Client
  alias FoPost.LogPage
  alias FoPost.Model
  alias FoPost.Result

  @list_params [
    :workspace_id,
    :days,
    :status,
    :method,
    :status_code,
    :platform,
    :route,
    :q,
    :limit,
    :before
  ]

  @doc """
  One page of request logs, newest first, with the window's totals on `:summary`.

  Filters: `:workspace_id`, `:days`, `:status`, `:method`, `:status_code`, `:platform`,
  `:route`, `:q`. Paging: `:limit`, `:before`.
  """
  @spec list(Client.t(), keyword()) :: {:ok, LogPage.t()} | {:error, FoPost.Error.t()}
  def list(client, opts \\ []) do
    params = Model.take_params(opts, @list_params)

    # The response carries meta and summary beside data, so it is read whole.
    with {:ok, data} <- Client.request(client, :get, "/logs", params: params, unwrap: false) do
      {:ok, LogPage.from_map(data)}
    end
  end

  @doc "Same as `list/2`, but raises `FoPost.Error`."
  def list!(client, opts \\ []), do: Result.unwrap!(list(client, opts))
end
