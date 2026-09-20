defmodule FoPost.KnowledgeSource do
  @moduledoc """
  One thing the workspace has told FoPost about itself: an FAQ, a note, a page
  on its own site, or a plain-text/CSV file from the media library.

  `:kind` is `"faq"`, `"text"`, `"url"` or `"file"`. `:status` is `"pending"`,
  `"syncing"`, `"ready"` or `"failed"`; only a ready source is searched.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :kind,
    :title,
    :status,
    :status_message,
    :url,
    :media_id,
    :brand_voice_id,
    :chunk_count,
    :content,
    :last_synced_at,
    :created_at,
    :updated_at,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      kind: fields["kind"],
      title: fields["title"],
      status: fields["status"],
      status_message: fields["status_message"],
      url: fields["url"],
      media_id: fields["media_id"],
      brand_voice_id: fields["brand_voice_id"],
      chunk_count: fields["chunk_count"],
      content: fields["content"],
      last_synced_at: Model.datetime(fields["last_synced_at"]),
      created_at: Model.datetime(fields["created_at"]),
      updated_at: Model.datetime(fields["updated_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.KnowledgeMatch do
  @moduledoc """
  One retrieved passage, with the source it came from so a reply can cite it.

  `:score` is the similarity to the question, 0-1.
  """

  alias FoPost.Model

  defstruct [:source_id, :source_title, :source_kind, :source_url, :text, :score, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      source_id: fields["source_id"],
      source_title: fields["source_title"],
      source_kind: fields["source_kind"],
      source_url: fields["source_url"],
      text: fields["text"],
      score: fields["score"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.KnowledgeSyncResult do
  @moduledoc """
  What a sync answers: the source, and that it is queued.
  """

  alias FoPost.Model

  defstruct [:id, :status, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{id: fields["id"], status: fields["status"], raw: data}
  end

  def from_map(_data), do: nil
end
