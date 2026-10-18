defmodule FoPost.Queue do
  @moduledoc """
  The posting queue: recurring weekly slots a post can be dropped into instead of
  being given a time.

      {:ok, slot} =
        FoPost.Queue.create_slot(client,
          workspace_id: workspace.id,
          weekday: 1,
          time: "09:00",
          timezone: "Europe/Zagreb"
        )

      {:ok, post} =
        FoPost.Posts.create(client,
          workspace_id: workspace.id,
          accounts: [account.id],
          content: "Hello",
          schedule: "queue"
        )

  A post created or updated with `schedule: "queue"` takes the next free slot. Every
  function needs the `posts` scope.
  """

  alias FoPost.Client
  alias FoPost.Model
  alias FoPost.QueueSlot
  alias FoPost.QueueSlotDeletion
  alias FoPost.Result

  @slot_fields [:account_id, :weekday, :time, :timezone]

  @doc """
  Every slot in a workspace.
  """
  @spec list_slots(Client.t(), String.t()) :: {:ok, [QueueSlot.t()]} | {:error, FoPost.Error.t()}
  def list_slots(client, workspace_id) do
    params = [{"workspace_id", workspace_id}]

    with {:ok, data} <- Client.request(client, :get, "/queue/slots", params: params) do
      {:ok, Model.list(QueueSlot, data)}
    end
  end

  @doc """
  Adds a slot.

  Required: `:workspace_id`, `:weekday` (`0` = Sunday … `6` = Saturday), `:time`
  (`HH:MM`, 24-hour), `:timezone` (an IANA zone name). Optional: `:account_id` to limit
  the slot to one account.
  """
  @spec create_slot(Client.t(), keyword()) :: {:ok, QueueSlot.t()} | {:error, FoPost.Error.t()}
  def create_slot(client, opts) do
    body =
      opts
      |> Model.take_body(@slot_fields)
      |> Map.put("workspace_id", Keyword.get(opts, :workspace_id))

    with {:ok, data} <- Client.request(client, :post, "/queue/slots", json: body) do
      {:ok, QueueSlot.from_map(data)}
    end
  end

  @doc """
  Edits a slot. Only the keys you pass are sent; `account_id: nil` makes the slot apply
  to every account. Queued posts the change moved come back on `:moved`.
  """
  @spec update_slot(Client.t(), String.t(), keyword()) ::
          {:ok, QueueSlot.t()} | {:error, FoPost.Error.t()}
  def update_slot(client, id, opts) do
    body = Model.take_body(opts, @slot_fields)

    with {:ok, data} <- Client.request(client, :put, path(id), json: body) do
      {:ok, QueueSlot.from_map(data)}
    end
  end

  @doc """
  Removes a slot. Posts queued into it move to the next slot and are listed on `:moved`.
  """
  @spec delete_slot(Client.t(), String.t()) ::
          {:ok, QueueSlotDeletion.t()} | {:error, FoPost.Error.t()}
  def delete_slot(client, id) do
    with {:ok, data} <- Client.request(client, :delete, path(id)) do
      {:ok, QueueSlotDeletion.from_map(data)}
    end
  end

  @doc """
  When the next queued post would go out, or `nil` when no slot applies.

  Options: `:account_id`.
  """
  @spec next(Client.t(), String.t(), keyword()) ::
          {:ok, DateTime.t() | nil} | {:error, FoPost.Error.t()}
  def next(client, workspace_id, opts \\ []) do
    params = [{"workspace_id", workspace_id} | Model.take_params(opts, [:account_id])]

    with {:ok, data} <- Client.request(client, :get, "/queue/next", params: params) do
      {:ok, Model.datetime(Model.normalize(data)["next"])}
    end
  end

  @doc """
  The next few times the queue would fill, in order.

  Options: `:account_id`, `:count`.
  """
  @spec preview(Client.t(), String.t(), keyword()) ::
          {:ok, [DateTime.t()]} | {:error, FoPost.Error.t()}
  def preview(client, workspace_id, opts \\ []) do
    params = [{"workspace_id", workspace_id} | Model.take_params(opts, [:account_id, :count])]

    with {:ok, data} <- Client.request(client, :get, "/queue/preview", params: params) do
      {:ok, data |> List.wrap() |> Enum.map(&Model.datetime/1)}
    end
  end

  @doc "Same as `list_slots/2`, but raises `FoPost.Error`."
  def list_slots!(client, workspace_id), do: Result.unwrap!(list_slots(client, workspace_id))

  @doc "Same as `create_slot/2`, but raises `FoPost.Error`."
  def create_slot!(client, opts), do: Result.unwrap!(create_slot(client, opts))

  @doc "Same as `update_slot/3`, but raises `FoPost.Error`."
  def update_slot!(client, id, opts), do: Result.unwrap!(update_slot(client, id, opts))

  @doc "Same as `delete_slot/2`, but raises `FoPost.Error`."
  def delete_slot!(client, id), do: Result.unwrap!(delete_slot(client, id))

  @doc "Same as `next/3`, but raises `FoPost.Error`."
  def next!(client, workspace_id, opts \\ []),
    do: Result.unwrap!(next(client, workspace_id, opts))

  @doc "Same as `preview/3`, but raises `FoPost.Error`."
  def preview!(client, workspace_id, opts \\ []) do
    Result.unwrap!(preview(client, workspace_id, opts))
  end

  defp path(id), do: "/queue/slots/" <> URI.encode(to_string(id), &URI.char_unreserved?/1)
end
