defmodule FoPost.MediaAsset do
  @moduledoc """
  One asset in a workspace's media library.

  `FoPost.Media.upload/2` answers with the same struct, shaped so it drops straight into a
  post's content block through `to_media_item/1`.
  """

  alias FoPost.MediaItem
  alias FoPost.Model

  defstruct [
    :id,
    :user_id,
    :workspace_id,
    :name,
    :url,
    :type,
    :mime_type,
    :size,
    :alt_text,
    :created_at,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc """
  Turns an uploaded asset into the media map a post's content block expects.
  """
  @spec to_media_item(t()) :: MediaItem.t()
  def to_media_item(%__MODULE__{} = asset) do
    %MediaItem{
      type: asset.type,
      name: asset.name,
      url: asset.url,
      size: asset.size,
      alt: asset.alt_text
    }
  end

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      user_id: fields["user_id"],
      workspace_id: fields["workspace_id"],
      name: fields["name"],
      url: fields["url"],
      type: fields["type"],
      mime_type: fields["mime_type"],
      size: fields["size"],
      alt_text: fields["alt_text"],
      created_at: Model.datetime(fields["created_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end
