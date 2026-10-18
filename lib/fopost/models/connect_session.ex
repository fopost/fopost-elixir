defmodule FoPost.ConnectSessionBranding do
  @moduledoc """
  The name and logo the hosted connect page shows in place of FoPost's own.
  """

  alias FoPost.Model

  defstruct [:name, :logo_url, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{name: fields["name"], logo_url: fields["logo_url"], raw: data}
  end

  def from_map(_data), do: nil
end

defmodule FoPost.ConnectSession do
  @moduledoc """
  A hosted connect link: one of your users opens `:url`, connects an account on one of
  `:platforms`, and the account lands in your workspace.

  `:url` is present on creation only. `:status` is `"pending"`, `"used"` or `"expired"`;
  once used, `:account_id` names the connected account.
  """

  alias FoPost.ConnectSessionBranding
  alias FoPost.Model

  defstruct [
    :id,
    :status,
    :external_user_id,
    :redirect_url,
    :branding,
    :account_id,
    :url,
    :expires_at,
    :used_at,
    :created_at,
    :raw,
    platforms: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      status: fields["status"],
      external_user_id: fields["external_user_id"],
      platforms: List.wrap(fields["platforms"]),
      redirect_url: fields["redirect_url"],
      branding: Model.build(ConnectSessionBranding, fields["branding"]),
      account_id: fields["account_id"],
      url: fields["url"],
      expires_at: Model.datetime(fields["expires_at"]),
      used_at: Model.datetime(fields["used_at"]),
      created_at: Model.datetime(fields["created_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end
