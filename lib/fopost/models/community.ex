defmodule FoPost.Community do
  @moduledoc """
  An X community linked to an account.

  `:id` is the local row id, which is what unlinks it; `:community_id` is X's own id.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :account_id,
    :community_id,
    :name,
    :member_count,
    :description,
    :image_url,
    :last_synced_at,
    :created_at,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      account_id: fields["account_id"],
      community_id: fields["community_id"],
      name: fields["name"],
      member_count: fields["member_count"],
      description: fields["description"],
      image_url: fields["image_url"],
      last_synced_at: Model.datetime(fields["last_synced_at"]),
      created_at: Model.datetime(fields["created_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.CommunitySearchResult do
  @moduledoc """
  A community as the platform's search returns it, before it is linked to an account.
  """

  alias FoPost.Model

  defstruct [:id, :name, :description, :member_count, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      description: fields["description"],
      member_count: fields["member_count"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end
