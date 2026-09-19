defmodule FoPost.Validate.PlatformResult do
  @moduledoc """
  One platform's readiness. `:issues` block publishing; `:signals` are advisory.
  """

  alias FoPost.Model

  defstruct [:platform, :ready, :score, :raw, issues: [], signals: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      platform: fields["platform"],
      ready: fields["ready"],
      score: fields["score"],
      issues: List.wrap(fields["issues"]),
      signals: Model.maps(fields["signals"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Validate.PostResult do
  @moduledoc """
  Content checked against every platform it targets. `:ready` is true only when every
  platform is.
  """

  alias FoPost.Model
  alias FoPost.Validate.PlatformResult

  defstruct [:ready, :raw, platforms: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      ready: fields["ready"],
      platforms: Model.list(PlatformResult, fields["platforms"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Validate.PlatformLength do
  @moduledoc """
  How one platform counts the text. `:limit` is nil when the platform has no text limit.
  """

  alias FoPost.Model

  defstruct [:platform, :length, :limit, :unit, :ok, :raw, signals: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      platform: fields["platform"],
      length: fields["length"],
      limit: fields["limit"],
      unit: fields["unit"],
      ok: fields["ok"],
      signals: Model.maps(fields["signals"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Validate.LengthResult do
  @moduledoc """
  Text measured against every platform it targets.
  """

  alias FoPost.Model
  alias FoPost.Validate.PlatformLength

  defstruct [:ok, :raw, platforms: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      ok: fields["ok"],
      platforms: Model.list(PlatformLength, fields["platforms"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Validate.MediaResult do
  @moduledoc """
  A fetched file checked against the media rules. `:mime_type` and `:type` are only
  present when `:ok` is true.
  """

  alias FoPost.Model

  defstruct [:ok, :name, :size, :mime_type, :type, :raw, issues: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      ok: fields["ok"],
      name: fields["name"],
      size: fields["size"],
      mime_type: fields["mime_type"],
      type: fields["type"],
      issues: List.wrap(fields["issues"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Validate.SubredditResult do
  @moduledoc """
  Whether a subreddit exists and takes a post from one account. `:ok` is true when both
  hold; a private, banned, or missing subreddit answers `exists: false` rather than failing.
  """

  alias FoPost.Model

  defstruct [:subreddit, :exists, :can_post, :over_18, :flair_enabled, :ok, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      subreddit: fields["subreddit"],
      exists: fields["exists"],
      can_post: fields["can_post"],
      over_18: fields["over_18"],
      flair_enabled: fields["flair_enabled"],
      ok: fields["ok"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end
