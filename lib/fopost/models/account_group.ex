defmodule FoPost.AccountGroup do
  @moduledoc """
  A named set of connected accounts in one workspace, which a post can target at once.
  """

  alias FoPost.Model

  defstruct [:id, :name, :account_ids, :created_at, :updated_at, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      account_ids: fields["account_ids"] || [],
      created_at: Model.datetime(fields["created_at"]),
      updated_at: Model.datetime(fields["updated_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end
