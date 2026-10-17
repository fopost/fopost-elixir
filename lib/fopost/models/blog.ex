defmodule FoPost.BlogSettings do
  @moduledoc """
  How a workspace plans, writes and publishes articles.

  `:target_kind` is `"product_blog"`, `"account"`, `"website"` or `nil`.
  `:image_tier` is `"draft"`, `"standard"` or `"best"`. `:goal` is `"traffic"`,
  `"leads"`, `"sales"`, `"signups"`, `"authority"` or `nil`.
  `:review_hold_days` is how many days before its planned date a picked keyword
  starts being written. `:plan_run` is the last keyword research run, `nil`
  before the first.

  `:website_secret` is set only on the result of `FoPost.Blog.update_settings/3`
  the first time `:website_url` is set, and nowhere else; `:has_website_secret`
  says whether one exists. Store it then.
  """

  alias FoPost.Model

  defstruct [
    :site_url,
    :topic,
    :audience,
    :goal,
    :focus_topics,
    :avoid_topics,
    :language,
    :location_code,
    :cadence_per_week,
    :review_hold_days,
    :image_tier,
    :in_body_images,
    :min_words,
    :max_words,
    :brand_voice_id,
    :target_kind,
    :target_account_id,
    :target_platform,
    :website_url,
    :has_website_secret,
    :plan_run,
    :keyword_data_available,
    :website_secret,
    :updated_at,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      site_url: fields["site_url"],
      topic: fields["topic"],
      audience: fields["audience"],
      goal: fields["goal"],
      focus_topics: fields["focus_topics"],
      avoid_topics: fields["avoid_topics"],
      language: fields["language"],
      location_code: fields["location_code"],
      cadence_per_week: fields["cadence_per_week"] || 0,
      review_hold_days: fields["review_hold_days"] || 0,
      image_tier: fields["image_tier"],
      in_body_images: fields["in_body_images"],
      min_words: fields["min_words"],
      max_words: fields["max_words"],
      brand_voice_id: fields["brand_voice_id"],
      target_kind: fields["target_kind"],
      target_account_id: fields["target_account_id"],
      target_platform: fields["target_platform"],
      website_url: fields["website_url"],
      has_website_secret: fields["has_website_secret"] || false,
      plan_run: Model.build(FoPost.BlogPlanRun, fields["plan_run"]),
      keyword_data_available: fields["keyword_data_available"] || false,
      website_secret: fields["website_secret"],
      updated_at: Model.datetime(fields["updated_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.BlogPlanRun do
  @moduledoc """
  The last keyword research run on a blog.

  `:status` is `"queued"`, `"running"`, `"done"` or `"failed"`; `:error` says
  why a run failed and `:added` counts the new keywords it found.
  """

  alias FoPost.Model

  defstruct [:status, :error, :added, :finished_at, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      status: fields["status"],
      error: fields["error"],
      added: fields["added"],
      finished_at: Model.datetime(fields["finished_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.BlogWebsiteTest do
  @moduledoc """
  What a test delivery to the website target came back with.

  `:ok` is whether the site answered 2xx; `:status` is its HTTP status and
  `:error` the transport failure when there was no status at all.
  """

  alias FoPost.Model

  defstruct [:ok, :status, :error, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      ok: fields["ok"] || false,
      status: fields["status"],
      error: fields["error"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.BlogKeyword do
  @moduledoc """
  One keyword on the plan.

  `:status` is `"suggested"`, `"planned"`, `"written"` or `"dismissed"`;
  `:source` is `"provider"`, `"user"` or `"agent"`. `:difficulty` is 0 to 100.
  `:planned_for` is a `Date`. `:fit_reason` says why the keyword serves the
  blog goal.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :keyword,
    :search_volume,
    :difficulty,
    :cpc,
    :intent,
    :source,
    :status,
    :planned_for,
    :fit_reason,
    :created_at,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      keyword: fields["keyword"],
      search_volume: fields["search_volume"],
      difficulty: fields["difficulty"],
      cpc: fields["cpc"],
      intent: fields["intent"],
      source: fields["source"],
      status: fields["status"],
      planned_for: Model.date(fields["planned_for"]),
      fit_reason: fields["fit_reason"],
      created_at: Model.datetime(fields["created_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.BlogArticleImage do
  @moduledoc """
  One image on an article.

  `:position` is the index of the outline heading the image sits under, and
  `nil` on the featured image.
  """

  alias FoPost.Model

  defstruct [:media_id, :url, :alt, :position, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      media_id: fields["media_id"],
      url: fields["url"],
      alt: fields["alt"],
      position: fields["position"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.BlogArticle do
  @moduledoc """
  An article as a list shows it, without its body.

  `:status` is `"queued"`, `"writing"`, `"draft"`, `"in_review"`,
  `"scheduled"`, `"publishing"`, `"published"`, `"failed"` or `"rejected"`; `:origin` is
  `"plan"`, `"user"` or `"agent"`. `:error` carries why a write or publish
  failed.
  """

  alias FoPost.BlogArticleImage
  alias FoPost.Model

  defstruct [
    :id,
    :title,
    :slug,
    :keyword,
    :excerpt,
    :meta_title,
    :meta_description,
    :featured_image,
    :word_count,
    :status,
    :origin,
    :review_until,
    :publish_at,
    :published_at,
    :published_url,
    :error,
    :created_at,
    :updated_at,
    :raw,
    tags: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      title: fields["title"],
      slug: fields["slug"],
      keyword: fields["keyword"],
      excerpt: fields["excerpt"],
      meta_title: fields["meta_title"],
      meta_description: fields["meta_description"],
      featured_image: Model.build(BlogArticleImage, fields["featured_image"]),
      tags: List.wrap(fields["tags"]),
      word_count: fields["word_count"] || 0,
      status: fields["status"],
      origin: fields["origin"],
      review_until: Model.datetime(fields["review_until"]),
      publish_at: Model.datetime(fields["publish_at"]),
      published_at: Model.datetime(fields["published_at"]),
      published_url: fields["published_url"],
      error: fields["error"],
      created_at: Model.datetime(fields["created_at"]),
      updated_at: Model.datetime(fields["updated_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.BlogArticleFull do
  @moduledoc """
  An article with its body, outline, brief and images.

  `:brief` is the research the writer worked from and passes through as a
  free-form map. Everything `FoPost.BlogArticle` carries is here too.
  """

  alias FoPost.BlogArticleImage
  alias FoPost.Model

  defstruct [
    :id,
    :title,
    :slug,
    :keyword,
    :excerpt,
    :meta_title,
    :meta_description,
    :featured_image,
    :word_count,
    :status,
    :origin,
    :review_until,
    :publish_at,
    :published_at,
    :published_url,
    :error,
    :created_at,
    :updated_at,
    :instructions,
    :brief,
    :body_markdown,
    :body_html,
    :raw,
    tags: [],
    outline: [],
    images: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      title: fields["title"],
      slug: fields["slug"],
      keyword: fields["keyword"],
      excerpt: fields["excerpt"],
      meta_title: fields["meta_title"],
      meta_description: fields["meta_description"],
      featured_image: Model.build(BlogArticleImage, fields["featured_image"]),
      tags: List.wrap(fields["tags"]),
      word_count: fields["word_count"] || 0,
      status: fields["status"],
      origin: fields["origin"],
      review_until: Model.datetime(fields["review_until"]),
      publish_at: Model.datetime(fields["publish_at"]),
      published_at: Model.datetime(fields["published_at"]),
      published_url: fields["published_url"],
      error: fields["error"],
      created_at: Model.datetime(fields["created_at"]),
      updated_at: Model.datetime(fields["updated_at"]),
      instructions: fields["instructions"],
      outline: List.wrap(fields["outline"]),
      brief: fields["brief"],
      body_markdown: fields["body_markdown"],
      body_html: fields["body_html"],
      images: Model.list(BlogArticleImage, fields["images"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.BlogArticlePublished do
  @moduledoc """
  The payload of an `article.published` delivery, and of the signed request a
  website target receives.

  Image URLs stay fetchable for six hours; download and store your own copy.
  Build it from a verified event with `from_map(event.data)`.
  """

  alias FoPost.BlogArticleImage
  alias FoPost.Model

  defstruct [
    :id,
    :title,
    :slug,
    :excerpt,
    :meta_title,
    :meta_description,
    :body_markdown,
    :body_html,
    :featured_image,
    :keyword,
    :word_count,
    :published_at,
    :published_url,
    :raw,
    images: [],
    tags: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      title: fields["title"],
      slug: fields["slug"],
      excerpt: fields["excerpt"],
      meta_title: fields["meta_title"],
      meta_description: fields["meta_description"],
      body_markdown: fields["body_markdown"],
      body_html: fields["body_html"],
      featured_image: Model.build(BlogArticleImage, fields["featured_image"]),
      images: Model.list(BlogArticleImage, fields["images"]),
      tags: List.wrap(fields["tags"]),
      keyword: fields["keyword"],
      word_count: fields["word_count"] || 0,
      published_at: Model.datetime(fields["published_at"]),
      published_url: fields["published_url"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end
