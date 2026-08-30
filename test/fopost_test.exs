defmodule FoPostTest do
  use ExUnit.Case, async: false

  test "version/0 matches the version the package ships as" do
    assert FoPost.version() == Mix.Project.config()[:version]
  end

  test "new/1 applies the documented defaults" do
    client = FoPost.new(api_key: "fp_key")

    assert client.api_key == "fp_key"
    assert client.base_url == "https://api.fopost.com/v1"
    assert client.receive_timeout == 30_000
    assert client.max_retries == 2
    assert client.user_agent == "fopost-elixir/" <> FoPost.version()
  end

  test "new/1 trims a trailing slash off the base URL" do
    client = FoPost.new(api_key: "k", base_url: "https://example.test/v1/")

    assert client.base_url == "https://example.test/v1"
  end

  test "new/1 falls back to the environment" do
    System.put_env("FOPOST_API_KEY", "fp_from_env")
    System.put_env("FOPOST_BASE_URL", "https://env.example.test/v1")

    on_exit(fn ->
      System.delete_env("FOPOST_API_KEY")
      System.delete_env("FOPOST_BASE_URL")
    end)

    client = FoPost.new()

    assert client.api_key == "fp_from_env"
    assert client.base_url == "https://env.example.test/v1"
  end

  test "explicit options beat application config, which beats the environment" do
    System.put_env("FOPOST_API_KEY", "fp_from_env")
    Application.put_env(:fopost, :api_key, "fp_from_config")

    on_exit(fn ->
      System.delete_env("FOPOST_API_KEY")
      Application.delete_env(:fopost, :api_key)
    end)

    assert FoPost.new().api_key == "fp_from_config"
    assert FoPost.new(api_key: "fp_explicit").api_key == "fp_explicit"
  end

  test "new/1 raises when no key can be found anywhere" do
    assert_raise ArgumentError, ~r/API key is required/, fn -> FoPost.new() end
  end
end
