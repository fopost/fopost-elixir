defmodule FoPost.Workspace do
  @moduledoc """
  One workspace — the tenant boundary every other resource is scoped to.
  """

  alias FoPost.Account
  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :slug,
    :type,
    :logo,
    :website,
    :timezone,
    :country,
    :description,
    :language,
    :require_approval,
    :ai_alt_text_enabled,
    :brand_color,
    :role,
    :created_at,
    :updated_at,
    :raw,
    accounts: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      slug: fields["slug"],
      type: fields["type"],
      logo: fields["logo"],
      website: fields["website"],
      timezone: fields["timezone"],
      country: fields["country"],
      description: fields["description"],
      language: fields["language"],
      require_approval: fields["require_approval"],
      ai_alt_text_enabled: fields["ai_alt_text_enabled"],
      brand_color: fields["brand_color"],
      role: fields["role"],
      accounts: Model.list(Account, fields["accounts"]),
      created_at: Model.datetime(fields["created_at"]),
      updated_at: Model.datetime(fields["updated_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.WorkspaceAnalytics do
  @moduledoc """
  A workspace's follower and post totals, per account and summed.
  """

  alias FoPost.Model

  defstruct [:workspace_id, :totals, :raw, accounts: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      workspace_id: fields["workspace_id"],
      accounts: Model.maps(fields["accounts"]),
      totals: Model.normalize(fields["totals"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end
