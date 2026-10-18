defmodule FoPost.XPost do
  @moduledoc """
  One X post read live through a connected X account, with its author and public
  metrics. `:conversation_id` is the thread root; `:parent_external_id` is the post this
  one replied to.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :text,
    :permalink,
    :author_name,
    :author_handle,
    :author_avatar_url,
    :author_followers,
    :conversation_id,
    :parent_external_id,
    :likes,
    :replies,
    :reposts,
    :quotes,
    :platform_created_at,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      text: fields["text"],
      permalink: fields["permalink"],
      author_name: fields["author_name"],
      author_handle: fields["author_handle"],
      author_avatar_url: fields["author_avatar_url"],
      author_followers: fields["author_followers"],
      conversation_id: fields["conversation_id"],
      parent_external_id: fields["parent_external_id"],
      likes: fields["likes"],
      replies: fields["replies"],
      reposts: fields["reposts"],
      quotes: fields["quotes"],
      platform_created_at: Model.datetime(fields["platform_created_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.XSearchPage do
  @moduledoc """
  One page of X search results. Pass `:next_token` back as `:next_token` for the next
  page; `nil` means there is none.
  """

  alias FoPost.Model
  alias FoPost.XPost

  defstruct [:next_token, :raw, posts: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      next_token: get_in(fields, ["meta", "next_token"]),
      posts: Model.list(XPost, fields["data"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end
