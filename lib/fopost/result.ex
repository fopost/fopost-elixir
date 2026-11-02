defmodule FoPost.Result do
  @moduledoc false

  # Backs the bang variant of every resource function.

  @spec unwrap!(:ok | {:ok, term()} | {:error, Exception.t()}) :: term()
  def unwrap!(:ok), do: :ok
  def unwrap!({:ok, result}), do: result
  def unwrap!({:error, error}), do: raise(error)
end
