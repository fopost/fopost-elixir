defmodule FoPost.Font do
  @moduledoc """
  A font file uploaded to a workspace. `:file_url` serves the file.
  """

  alias FoPost.Model

  defstruct [:id, :family, :style, :weight, :format, :file_url, :created_at, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      family: fields["family"],
      style: fields["style"],
      weight: fields["weight"],
      format: fields["format"],
      file_url: fields["file_url"],
      created_at: Model.datetime(fields["created_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.LibraryFont do
  @moduledoc """
  A family from the built-in font library. Each of `:files` is a map of `"path"`,
  `"subset"`, `"weight"`, `"style"`, and `"unicode_range"`.
  """

  alias FoPost.Model

  defstruct [:slug, :family, :category, :raw, scripts: [], weights: [], files: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      slug: fields["slug"],
      family: fields["family"],
      category: fields["category"],
      scripts: fields["scripts"] || [],
      weights: fields["weights"] || [],
      files: fields["files"] || [],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.FontList do
  @moduledoc """
  What `FoPost.Fonts.list/2` answers: the built-in library, and the workspace's own
  uploads when a workspace was given.
  """

  alias FoPost.Font
  alias FoPost.LibraryFont
  alias FoPost.Model

  defstruct [:raw, library: [], uploaded: []]

  @type t :: %__MODULE__{library: [LibraryFont.t()], uploaded: [Font.t()]}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      library: Model.list(LibraryFont, fields["library"]),
      uploaded: Model.list(Font, fields["uploaded"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end
