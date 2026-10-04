defmodule FoPost.Activity do
  @moduledoc """
  Activity — what happened in a workspace, including the security audit log.
  """

  alias FoPost.ActivityPage
  alias FoPost.Client
  alias FoPost.Model

  @list_params [:workspace_id, :kind, :from, :to, :cursor, :limit]

  @doc """
  One page of activity, newest first. Omit `:workspace_id` to read every workspace
  the key can reach.

  Filters: `:workspace_id`, `:kind`, `:from`, `:to`. Paging: `:cursor`, `:limit`.

  `kind: "security"` is the audit log: members joining, leaving or changing role
  and access, and changes to two-step verification, passkeys, single sign-on and
  signed-in devices. Those rows are append-only and never expire.
  """
  @spec list(Client.t(), keyword()) :: {:ok, ActivityPage.t()} | {:error, FoPost.Error.t()}
  def list(client, opts \\ []) do
    params = Model.take_params(opts, @list_params)

    # The response carries meta beside data, so it is read whole.
    with {:ok, data} <- Client.request(client, :get, "/activity", params: params, unwrap: false) do
      {:ok, ActivityPage.from_map(data)}
    end
  end
end
