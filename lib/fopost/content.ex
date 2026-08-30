defmodule FoPost.MediaItem do
  @moduledoc """
  One attachment on a content block.
  """

  alias FoPost.Model

  defstruct [:type, :name, :url, :size, :alt, :thumbnail, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      type: fields["type"],
      name: fields["name"],
      url: fields["url"],
      size: fields["size"],
      alt: fields["alt"],
      thumbnail: fields["thumbnail"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.ContentBlock do
  @moduledoc """
  One text-plus-media unit of a post. A single post has one block; a thread has one per
  entry, in order.
  """

  alias FoPost.MediaItem
  alias FoPost.Model

  defstruct [:id, :text, :position, :raw, media: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      text: fields["text"],
      position: fields["position"],
      media: Model.list(MediaItem, fields["media"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Content do
  @moduledoc """
  Builds the `:content` a post is created or updated with.

  `FoPost.Posts.create/2` accepts any of these shapes and normalises them for you, so
  reach for this module only when you want to build the blocks yourself:

      FoPost.Content.text("One post")
      FoPost.Content.thread(["First", "Second", "Third"])

  A block is a map of `text` plus an optional list of `media`, each item a map of `type`
  (`"image"`, `"video"`, or `"gif"`), `name`, and `url`.
  """

  alias FoPost.ContentBlock
  alias FoPost.MediaItem
  alias FoPost.Model

  @doc """
  One block holding a single piece of text.
  """
  @spec text(String.t()) :: [map()]
  def text(text) when is_binary(text), do: [%{"text" => text}]

  @doc """
  One block per entry, in order — a thread.
  """
  @spec thread([String.t() | map() | ContentBlock.t()]) :: [map()]
  def thread(entries) when is_list(entries), do: Enum.map(entries, &block/1)

  @doc false
  def normalize(nil), do: []
  def normalize(content) when is_binary(content), do: [block(content)]
  def normalize(content) when is_list(content), do: Enum.map(content, &block/1)
  def normalize(content), do: [block(content)]

  defp block(text) when is_binary(text), do: %{"text" => text}

  defp block(%ContentBlock{} = block) do
    %{"text" => block.text}
    |> put_media(block.media)
    |> Model.put_present("position", block.position)
  end

  defp block(%{} = block) do
    block
    |> Map.delete(:__struct__)
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
    |> normalize_media()
  end

  defp put_media(block, nil), do: block
  defp put_media(block, []), do: block

  defp put_media(block, media) when is_list(media) do
    Map.put(block, "media", Enum.map(media, &media_item/1))
  end

  defp put_media(block, media), do: Map.put(block, "media", [media_item(media)])

  defp normalize_media(%{"media" => media} = block) when is_list(media) do
    Map.put(block, "media", Enum.map(media, &media_item/1))
  end

  defp normalize_media(block), do: block

  defp media_item(%MediaItem{} = item) do
    %{"type" => item.type, "name" => item.name, "url" => item.url}
    |> Model.put_present("alt", item.alt)
  end

  defp media_item(%{} = item) do
    item
    |> Map.delete(:__struct__)
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
  end

  defp media_item(item), do: item
end
