defmodule FoPost.Label do
  @moduledoc """
  A campaign tag posts are grouped and reported by.
  """

  alias FoPost.Model

  defstruct [:id, :name, :color, :workspace, :created_at, :updated_at, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      color: fields["color"],
      workspace: Model.normalize(fields["workspace"]),
      created_at: Model.datetime(fields["created_at"]),
      updated_at: Model.datetime(fields["updated_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end
