defmodule FoPost.PinterestBoard do
  @moduledoc """
  A Pinterest board a Pin can land on. Pass `:id` as the `board_id` platform setting to
  pin to it.
  """

  alias FoPost.Model

  defstruct [:id, :name, :privacy, :description, :image, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      privacy: fields["privacy"],
      description: fields["description"],
      image: fields["image"],
      raw: data
    }
  end
end

defmodule FoPost.YouTubePlaylist do
  @moduledoc """
  A playlist on the connected channel. `:is_default` marks the one a new video joins when
  the post picks none.
  """

  alias FoPost.Model

  defstruct [:id, :title, :description, :privacy, :item_count, :thumbnail_url, :is_default, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      title: fields["title"],
      description: fields["description"],
      privacy: fields["privacy"],
      item_count: fields["item_count"],
      thumbnail_url: fields["thumbnail_url"],
      is_default: fields["is_default"],
      raw: data
    }
  end
end

defmodule FoPost.YouTubeCaptionTrack do
  @moduledoc """
  A caption track on one of the channel's videos. `:language` is a BCP-47 tag.
  """

  alias FoPost.Model

  defstruct [:id, :language, :name, :track_kind, :is_draft, :is_auto_synced, :last_updated, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      language: fields["language"],
      name: fields["name"],
      track_kind: fields["track_kind"],
      is_draft: fields["is_draft"],
      is_auto_synced: fields["is_auto_synced"],
      last_updated: fields["last_updated"],
      raw: data
    }
  end
end

defmodule FoPost.YouTubeTranscript do
  @moduledoc """
  One caption track read back as text. `:transcript` is SRT.
  """

  alias FoPost.Model

  defstruct [:caption_id, :transcript, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      caption_id: fields["caption_id"],
      transcript: fields["transcript"],
      raw: data
    }
  end
end

defmodule FoPost.BlueskyLanguages do
  @moduledoc """
  The default post languages for a connection: up to three BCP-47 tags.
  """

  alias FoPost.Model

  defstruct [:languages, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{languages: fields["languages"] || [], raw: data}
  end
end

defmodule FoPost.TikTokCreatorInfo do
  @moduledoc """
  The switches TikTok enforces at publish time. They are set on the TikTok account itself,
  not in FoPost, so a disabled one cannot be turned back on here.
  """

  alias FoPost.Model

  defstruct [
    :username,
    :nickname,
    :avatar_url,
    :privacy_level_options,
    :comment_disabled,
    :duet_disabled,
    :stitch_disabled,
    :max_video_post_duration_sec,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      username: fields["username"],
      nickname: fields["nickname"],
      avatar_url: fields["avatar_url"],
      privacy_level_options: fields["privacy_level_options"] || [],
      comment_disabled: fields["comment_disabled"],
      duet_disabled: fields["duet_disabled"],
      stitch_disabled: fields["stitch_disabled"],
      max_video_post_duration_sec: fields["max_video_post_duration_sec"],
      raw: data
    }
  end
end

defmodule FoPost.InstagramAudio do
  @moduledoc """
  A track a Reel can carry. Pass `:id` as the `audio_id` platform setting.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :title,
    :artist,
    :duration_ms,
    :audio_type,
    :cover_artwork_url,
    :preview_url,
    :username,
    :is_ads_eligible,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      title: fields["title"],
      artist: fields["artist"],
      duration_ms: fields["duration_ms"],
      audio_type: fields["audio_type"],
      cover_artwork_url: fields["cover_artwork_url"],
      preview_url: fields["preview_url"],
      username: fields["username"],
      is_ads_eligible: fields["is_ads_eligible"],
      raw: data
    }
  end
end

defmodule FoPost.InstagramPublishingLimit do
  @moduledoc """
  What this account has published in the rolling window, and what is left.
  """

  alias FoPost.Model

  defstruct [:quota_usage, :quota_total, :quota_duration_sec, :remaining, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      quota_usage: fields["quota_usage"],
      quota_total: fields["quota_total"],
      quota_duration_sec: fields["quota_duration_sec"],
      remaining: fields["remaining"],
      raw: data
    }
  end
end

defmodule FoPost.InstagramStory do
  @moduledoc """
  A story still inside its 24 hours. `:insights` is present only when asked for.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :media_type,
    :media_product_type,
    :permalink,
    :media_url,
    :thumbnail_url,
    :caption,
    :timestamp,
    :insights,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      media_type: fields["media_type"],
      media_product_type: fields["media_product_type"],
      permalink: fields["permalink"],
      media_url: fields["media_url"],
      thumbnail_url: fields["thumbnail_url"],
      caption: fields["caption"],
      timestamp: fields["timestamp"],
      insights: fields["insights"],
      raw: data
    }
  end
end

defmodule FoPost.InstagramStoryInsights do
  @moduledoc """
  The insight set for one story.
  """

  alias FoPost.Model

  defstruct [:story_id, :insights, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      story_id: fields["story_id"],
      insights: fields["insights"] || %{},
      raw: data
    }
  end
end

defmodule FoPost.LinkedInMention do
  @moduledoc """
  An entity a post can mention. `:annotation` is what the post text carries for LinkedIn
  to render a link.
  """

  alias FoPost.Model

  defstruct [:urn, :name, :vanity_name, :logo_url, :type, :annotation, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      urn: fields["urn"],
      name: fields["name"],
      vanity_name: fields["vanity_name"],
      logo_url: fields["logo_url"],
      type: fields["type"],
      annotation: fields["annotation"],
      raw: data
    }
  end
end

defmodule FoPost.TikTokMusic do
  @moduledoc """
  A track from TikTok's Commercial Music Library. Pass `:id` as the `music_id` platform
  setting to attach it to a post.
  """

  alias FoPost.Model

  defstruct [:id, :title, :author, :duration_sec, :cover_url, :preview_url, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      title: fields["title"],
      author: fields["author"],
      duration_sec: fields["duration_sec"],
      cover_url: fields["cover_url"],
      preview_url: fields["preview_url"],
      raw: data
    }
  end
end

defmodule FoPost.TikTokPlace do
  @moduledoc """
  A place a post can be tagged with. Pass `:id` as the `location_id` platform setting.
  """

  alias FoPost.Model

  defstruct [:id, :name, :address, :city, :country, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      address: fields["address"],
      city: fields["city"],
      country: fields["country"],
      raw: data
    }
  end
end

defmodule FoPost.TikTokVideoSource do
  @moduledoc """
  One of the account's own videos, resolved from a share link. TikTok serves no raw media
  file, so `:download_url` is the share address, which is what a repurpose run reads.
  """

  alias FoPost.Model

  defstruct [
    :video_id,
    :title,
    :description,
    :duration_sec,
    :cover_image_url,
    :share_url,
    :embed_link,
    :download_url,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      video_id: fields["video_id"],
      title: fields["title"],
      description: fields["description"],
      duration_sec: fields["duration_sec"],
      cover_image_url: fields["cover_image_url"],
      share_url: fields["share_url"],
      embed_link: fields["embed_link"],
      download_url: fields["download_url"],
      raw: data
    }
  end
end
