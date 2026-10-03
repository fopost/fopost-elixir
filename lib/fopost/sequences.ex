defmodule FoPost.Sequences do
  @moduledoc """
  Drip sequences — a series of messages, each a delay after the one before,
  walked per enrolled contact.

  The messaging window applies to every step. A step that comes due outside it
  is skipped rather than sent, and the enrollment carries on — so someone can
  complete a sequence having received only some of its messages.

  Reading needs the `inbox` scope; `enroll/3` and `unenroll/3` also need
  `publish`.
  """

  alias FoPost.Client
  alias FoPost.Enrolled
  alias FoPost.Enrollment
  alias FoPost.Model
  alias FoPost.Page
  alias FoPost.Sequence
  alias FoPost.Unenrolled

  @list_params [:workspace_id, :page, :per_page]
  @enrollment_params [:page, :per_page]
  @create_body [:workspace_id, :account_id, :name, :steps, :status]
  @update_body [:name, :steps, :status]

  @doc """
  Sequences. Options: `:workspace_id`, `:page`, `:per_page`.
  """
  @spec list(Client.t(), keyword()) :: {:ok, Page.t()} | {:error, FoPost.Error.t()}
  def list(client, opts \\ []) do
    params = Model.take_params(opts, @list_params)

    with {:ok, data} <- Client.request(client, :get, "/sequences", params: params, unwrap: false) do
      {:ok, page(data, Sequence)}
    end
  end

  @doc "One sequence."
  @spec get(Client.t(), String.t()) :: {:ok, Sequence.t()} | {:error, FoPost.Error.t()}
  def get(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id)) do
      {:ok, Sequence.from_map(data)}
    end
  end

  @doc """
  Writes a sequence. Creating one enrolls nobody.

  Required: `:workspace_id`, `:account_id`, `:name` and `:steps`, a list of
  maps carrying `delay_hours` and `text`. Optional: `:status`, `"active"` by
  default.
  """
  @spec create(Client.t(), keyword()) :: {:ok, Sequence.t()} | {:error, FoPost.Error.t()}
  def create(client, opts) do
    body = Model.take_body(opts, @create_body)

    with {:ok, data} <- Client.request(client, :post, "/sequences", json: body) do
      {:ok, Sequence.from_map(data)}
    end
  end

  @doc """
  Changes a sequence.

  Pausing stops every enrollment from firing without ending any of them;
  resuming picks them up where they stood.
  """
  @spec update(Client.t(), String.t(), keyword()) ::
          {:ok, Sequence.t()} | {:error, FoPost.Error.t()}
  def update(client, id, opts) do
    body = Model.take_body(opts, @update_body)

    with {:ok, data} <- Client.request(client, :patch, path(id), json: body) do
      {:ok, Sequence.from_map(data)}
    end
  end

  @doc """
  Puts contacts on the sequence, by `:contact_ids` or by `:audience`.

  Re-enrolling someone restarts their walk from the first step rather than
  running two in parallel. Needs `publish` as well as `inbox`.
  """
  @spec enroll(Client.t(), String.t(), keyword()) ::
          {:ok, Enrolled.t()} | {:error, FoPost.Error.t()}
  def enroll(client, id, opts) do
    body = Model.take_body(opts, [:contact_ids, :audience])

    with {:ok, data} <- Client.request(client, :post, path(id) <> "/enroll", json: body) do
      {:ok, Enrolled.from_map(data)}
    end
  end

  @doc """
  Takes contacts off the sequence. Nothing further fires for them.

  Needs the `publish` scope.
  """
  @spec unenroll(Client.t(), String.t(), [String.t()]) ::
          {:ok, Unenrolled.t()} | {:error, FoPost.Error.t()}
  def unenroll(client, id, contact_ids) do
    body = %{"contact_ids" => contact_ids}

    with {:ok, data} <- Client.request(client, :post, path(id) <> "/unenroll", json: body) do
      {:ok, Unenrolled.from_map(data)}
    end
  end

  @doc """
  Who is on the sequence, what step they are at, and when the next one is due.

  Options: `:page`, `:per_page`.
  """
  @spec enrollments(Client.t(), String.t(), keyword()) ::
          {:ok, Page.t()} | {:error, FoPost.Error.t()}
  def enrollments(client, id, opts \\ []) do
    params = Model.take_params(opts, @enrollment_params)

    with {:ok, data} <-
           Client.request(client, :get, path(id) <> "/enrollments",
             params: params,
             unwrap: false
           ) do
      {:ok, page(data, Enrollment)}
    end
  end

  @doc "Removes a sequence and every enrollment on it."
  @spec delete(Client.t(), String.t()) :: {:ok, map()} | {:error, FoPost.Error.t()}
  def delete(client, id) do
    Client.request(client, :delete, path(id))
  end

  defp page(body, module) when is_map(body) do
    Page.from_map(Map.put(body, "meta", Map.get(body, "pagination")), module)
  end

  defp page(_body, _module), do: %Page{}

  defp path(id), do: "/sequences/" <> URI.encode(to_string(id))
end
