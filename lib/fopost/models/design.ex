defmodule FoPost.Design do
  @moduledoc """
  A design: a story, post, carousel, thumbnail, card, or collage.

  `:document` is the editor's document, kept exactly as the API sent it (string keys),
  so it can be edited and passed back to `FoPost.Designs.update/3`. Lists leave it `nil`.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :kind,
    :width,
    :height,
    :document,
    :thumbnail_media_id,
    :thumbnail_url,
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
      name: fields["name"],
      kind: fields["kind"],
      width: fields["width"],
      height: fields["height"],
      document: fields["document"],
      thumbnail_media_id: fields["thumbnail_media_id"],
      thumbnail_url: fields["thumbnail_url"],
      created_at: Model.datetime(fields["created_at"]),
      updated_at: Model.datetime(fields["updated_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.DesignVersion do
  @moduledoc """
  A saved version of a design. `:document` is `nil` unless the listing asked for it.
  """

  alias FoPost.Model

  defstruct [:id, :version, :document, :created_at, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      version: fields["version"],
      document: fields["document"],
      created_at: Model.datetime(fields["created_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.DesignChange do
  @moduledoc """
  What an update or a version restore answers: the design, and the version saved with
  the change (`nil` when none was).
  """

  alias FoPost.Design
  alias FoPost.DesignVersion
  alias FoPost.Model

  defstruct [:design, :version, :raw]

  @type t :: %__MODULE__{design: Design.t() | nil, version: DesignVersion.t() | nil}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      design: Model.build(Design, fields["data"]),
      version: Model.build(DesignVersion, fields["version"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.DesignDeletion do
  @moduledoc """
  What `FoPost.Designs.delete/2` answers.
  """

  alias FoPost.Model

  defstruct [:id, :deleted, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{id: fields["id"], deleted: fields["deleted"], raw: data}
  end

  def from_map(_data), do: nil
end

defmodule FoPost.DesignExportFile do
  @moduledoc """
  One exported file, saved to the media library. `:page_index` is the page it rendered.
  """

  alias FoPost.Model

  defstruct [:media_id, :page_index, :mime_type, :preview_url, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      media_id: fields["media_id"],
      page_index: fields["page_index"],
      mime_type: fields["mime_type"],
      preview_url: fields["preview_url"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.DesignExport do
  @moduledoc """
  What `FoPost.Designs.export/3` answers: the format and one file per exported page.
  """

  alias FoPost.DesignExportFile
  alias FoPost.Model

  defstruct [:format, :raw, files: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      format: fields["format"],
      files: Model.list(DesignExportFile, fields["files"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.DesignPost do
  @moduledoc """
  A post that used a design, with its combined engagement and views where measured.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :status,
    :title,
    :text,
    :schedule_at,
    :published_at,
    :engagement,
    :views,
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
      title: fields["title"],
      text: fields["text"],
      schedule_at: Model.datetime(fields["schedule_at"]),
      published_at: Model.datetime(fields["published_at"]),
      platforms: fields["platforms"] || [],
      engagement: fields["engagement"],
      views: fields["views"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.SlideOutline do
  @moduledoc """
  What `FoPost.Designs.text_to_slides/2` answers: a cover, the slides, a closing call to
  action, and the brand style to render them with. Each slide is a map of `"heading"`
  and `"body"`; `:brand` has `"colors"`, `"fonts"`, and `"logo_media_id"`.
  """

  alias FoPost.Model

  defstruct [:cover, :cta, :brand, :raw, slides: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      cover: fields["cover"],
      slides: fields["slides"] || [],
      cta: fields["cta"],
      brand: fields["brand"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end
