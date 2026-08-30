defmodule FoPost.Automations do
  @moduledoc """
  Automations — a trigger plus the steps it runs.

      {:ok, automation} =
        FoPost.Automations.create(client,
          workspace_id: workspace.id,
          name: "Cross-post the blog",
          trigger_type: "rss_feed",
          trigger_config: %{"url" => "https://example.com/feed.xml"},
          steps: [%{action_type: "publish", action_config: %{"accounts" => [account.id]}}]
        )

  A step is a `FoPost.AutomationStep` or a map of `:action_type` and `:action_config`;
  snake_case keys are converted to the wire's camelCase for you.
  """

  alias FoPost.Automation
  alias FoPost.AutomationRun
  alias FoPost.AutomationStats
  alias FoPost.AutomationStep
  alias FoPost.AutomationTrigger
  alias FoPost.Client
  alias FoPost.Message
  alias FoPost.Model
  alias FoPost.Page
  alias FoPost.Result

  @fields [
    {:workspace_id, "workspaceId"},
    :name,
    {:trigger_type, "triggerType"},
    {:trigger_config, "triggerConfig"},
    :active
  ]

  @doc """
  The automations the key can reach.
  """
  @spec list(Client.t()) :: {:ok, [Automation.t()]} | {:error, FoPost.Error.t()}
  def list(client) do
    with {:ok, data} <- Client.request(client, :get, "/automations") do
      {:ok, Model.list(Automation, data)}
    end
  end

  @doc """
  One automation, with its steps.
  """
  @spec get(Client.t(), String.t()) :: {:ok, Automation.t()} | {:error, FoPost.Error.t()}
  def get(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id)) do
      {:ok, Automation.from_map(data)}
    end
  end

  @doc """
  Adds an automation.

  Required: `:workspace_id`, `:name`, `:trigger_type`, `:steps`. Optional:
  `:trigger_config`, `:active`.

  For an `api_webhook` trigger the response carries the signing secret once — store it.
  """
  @spec create(Client.t(), keyword()) :: {:ok, Automation.t()} | {:error, FoPost.Error.t()}
  def create(client, opts) do
    body = opts |> Model.take_body(@fields) |> put_steps(opts)

    with {:ok, data} <- Client.request(client, :post, "/automations", json: body) do
      {:ok, Automation.from_map(data)}
    end
  end

  @doc """
  Edits an automation. Only the keys you pass are sent, but `:steps` replaces the whole
  list when given.
  """
  @spec update(Client.t(), String.t(), keyword()) ::
          {:ok, Automation.t()} | {:error, FoPost.Error.t()}
  def update(client, id, opts) do
    body = opts |> Model.take_body(@fields) |> put_steps(opts)

    with {:ok, data} <- Client.request(client, :put, path(id), json: body) do
      {:ok, Automation.from_map(data)}
    end
  end

  @doc """
  Removes an automation.
  """
  @spec delete(Client.t(), String.t()) :: {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def delete(client, id) do
    with {:ok, data} <- Client.request(client, :delete, path(id)) do
      {:ok, Message.from_map(data)}
    end
  end

  @doc """
  Switches an automation on or off.
  """
  @spec toggle(Client.t(), String.t()) :: {:ok, Automation.t()} | {:error, FoPost.Error.t()}
  def toggle(client, id) do
    with {:ok, data} <- Client.request(client, :post, path(id) <> "/toggle") do
      {:ok, Automation.from_map(data)}
    end
  end

  @doc """
  One page of an automation's executions. Paging: `:page`, `:per_page`.
  """
  @spec runs(Client.t(), String.t(), keyword()) :: {:ok, Page.t()} | {:error, FoPost.Error.t()}
  def runs(client, id, opts \\ []) do
    params = Model.take_params(opts, [:page, :per_page])
    url_path = path(id) <> "/runs"

    with {:ok, data} <- Client.request(client, :get, url_path, params: params, unwrap: false) do
      {:ok, Page.from_map(data, AutomationRun)}
    end
  end

  @doc """
  One execution, with a log per step.
  """
  @spec run(Client.t(), String.t(), String.t() | integer()) ::
          {:ok, AutomationRun.t()} | {:error, FoPost.Error.t()}
  def run(client, id, run_id) do
    url_path = path(id) <> "/runs/" <> segment(run_id)

    with {:ok, data} <- Client.request(client, :get, url_path) do
      {:ok, AutomationRun.from_map(data)}
    end
  end

  @doc """
  Fires an `api_webhook` automation with a payload its steps can read.
  """
  @spec trigger(Client.t(), String.t(), map()) ::
          {:ok, AutomationTrigger.t()} | {:error, FoPost.Error.t()}
  def trigger(client, id, payload \\ %{}) do
    url_path = path(id) <> "/trigger"

    with {:ok, data} <- Client.request(client, :post, url_path, json: payload) do
      {:ok, AutomationTrigger.from_map(data)}
    end
  end

  @doc """
  Automation counts and the runs of the last day.
  """
  @spec stats(Client.t()) :: {:ok, AutomationStats.t()} | {:error, FoPost.Error.t()}
  def stats(client) do
    with {:ok, data} <- Client.request(client, :get, "/automations/stats") do
      {:ok, AutomationStats.from_map(data)}
    end
  end

  @doc "Same as `list/1`, but raises `FoPost.Error`."
  def list!(client), do: Result.unwrap!(list(client))

  @doc "Same as `get/2`, but raises `FoPost.Error`."
  def get!(client, id), do: Result.unwrap!(get(client, id))

  @doc "Same as `create/2`, but raises `FoPost.Error`."
  def create!(client, opts), do: Result.unwrap!(create(client, opts))

  @doc "Same as `update/3`, but raises `FoPost.Error`."
  def update!(client, id, opts), do: Result.unwrap!(update(client, id, opts))

  @doc "Same as `delete/2`, but raises `FoPost.Error`."
  def delete!(client, id), do: Result.unwrap!(delete(client, id))

  @doc "Same as `toggle/2`, but raises `FoPost.Error`."
  def toggle!(client, id), do: Result.unwrap!(toggle(client, id))

  @doc "Same as `runs/3`, but raises `FoPost.Error`."
  def runs!(client, id, opts \\ []), do: Result.unwrap!(runs(client, id, opts))

  @doc "Same as `run/3`, but raises `FoPost.Error`."
  def run!(client, id, run_id), do: Result.unwrap!(run(client, id, run_id))

  @doc "Same as `trigger/3`, but raises `FoPost.Error`."
  def trigger!(client, id, payload \\ %{}) do
    Result.unwrap!(trigger(client, id, payload))
  end

  @doc "Same as `stats/1`, but raises `FoPost.Error`."
  def stats!(client), do: Result.unwrap!(stats(client))

  defp put_steps(body, opts) do
    case Keyword.fetch(opts, :steps) do
      {:ok, steps} -> Map.put(body, "steps", Enum.map(List.wrap(steps), &step/1))
      :error -> body
    end
  end

  defp step(%AutomationStep{} = step) do
    %{"actionType" => step.action_type}
    |> Model.put_present("actionConfig", step.action_config)
    |> Model.put_present("position", step.position)
  end

  defp step(%{} = step) do
    step
    |> Map.delete(:__struct__)
    |> Map.new(fn {key, value} -> {Model.camel(key), value} end)
  end

  defp path(id), do: "/automations/" <> segment(id)

  defp segment(value), do: URI.encode(to_string(value), &URI.char_unreserved?/1)
end
