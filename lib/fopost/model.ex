defmodule FoPost.Model do
  @moduledoc false

  # Decoding helpers shared by every struct in the SDK.
  #
  # The API is not consistent about its wire casing — posts come back snake_case, accounts
  # camelCase, workspaces a mix — so every key is normalised to a snake_case string before
  # a struct reads it. Each struct also keeps the decoded body on `:raw`, so a field the
  # SDK does not model yet is never lost.

  def normalize(data) when is_map(data) and not is_struct(data) do
    Map.new(data, fn {key, value} -> {snake(key), value} end)
  end

  def normalize(_data), do: %{}

  def snake(key) do
    key
    |> to_string()
    |> String.replace(~r/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
    |> String.replace(~r/([a-z\d])([A-Z])/, "\\1_\\2")
    |> String.downcase()
  end

  def build(module, data) when is_map(data) and not is_struct(data), do: module.from_map(data)
  def build(_module, _data), do: nil

  def list(module, data) when is_list(data), do: Enum.map(data, &module.from_map/1)
  def list(_module, _data), do: []

  def maps(data) when is_list(data), do: Enum.map(data, &normalize/1)
  def maps(_data), do: []

  def datetime(nil), do: nil
  def datetime(%DateTime{} = value), do: value

  def datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      {:error, _reason} -> naive_datetime(value)
    end
  end

  def datetime(_value), do: nil

  def to_iso8601(nil), do: nil
  def to_iso8601(%DateTime{} = value), do: DateTime.to_iso8601(value)
  def to_iso8601(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value) <> "Z"
  def to_iso8601(%Date{} = value), do: Date.to_iso8601(value)
  def to_iso8601(value) when is_binary(value), do: value

  # A key the caller never passed is left out of the body entirely, so a PUT stays a
  # partial update. A key passed as nil is sent as null, which is how a field is cleared.
  def take_body(opts, keys) do
    Enum.reduce(keys, %{}, fn key, body ->
      case Keyword.fetch(opts, key) do
        {:ok, value} -> Map.put(body, Atom.to_string(key), value)
        :error -> body
      end
    end)
  end

  def take_params(opts, keys) do
    opts
    |> Keyword.take(keys)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  def put_present(map, _key, nil), do: map
  def put_present(map, key, value), do: Map.put(map, key, value)

  defp naive_datetime(value) do
    case NaiveDateTime.from_iso8601(value) do
      {:ok, naive} -> DateTime.from_naive!(naive, "Etc/UTC")
      {:error, _reason} -> date(value)
    end
  end

  defp date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      {:error, _reason} -> nil
    end
  end
end
