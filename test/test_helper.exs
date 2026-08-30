ExUnit.start()

# Nothing in the suite may reach the real API, and nothing may depend on the machine it
# runs on, so the environment starts empty.
System.delete_env("FOPOST_API_KEY")
System.delete_env("FOPOST_BASE_URL")

defmodule FoPost.TestSupport do
  @moduledoc false

  def client(bypass, opts \\ []) do
    defaults = [
      api_key: "fp_test_key",
      base_url: "http://localhost:#{bypass.port}/v1",
      req_options: [retry_delay: fn _attempt -> 0 end]
    ]

    FoPost.new(Keyword.merge(defaults, opts))
  end

  def json(conn, status, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(status, Jason.encode!(body))
  end

  def counter do
    {:ok, agent} = Agent.start_link(fn -> 0 end)

    agent
  end

  def bump(agent), do: Agent.get_and_update(agent, fn count -> {count + 1, count + 1} end)

  def count(agent), do: Agent.get(agent, & &1)
end
