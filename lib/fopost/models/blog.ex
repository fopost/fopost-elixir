defmodule FoPost.RemoteBlog do
  @moduledoc """
  A blog on a connected site.

  `id` is the platform's own id, never a FoPost id. A Shopify store reports every
  blog it has; WordPress has one implicit blog and reports it under the id
  `"default"`, so both answer the same shape.
  """

  alias FoPost.Model

  defstruct [:id, :title, :handle, :url, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      title: fields["title"],
      handle: fields["handle"],
      url: fields["url"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.RemoteArticle do
  @moduledoc """
  An article that already lives on a connected site, addressed by the platform's
  own id.

  `status` is one of `"published"`, `"draft"`, `"pending"` or `"scheduled"`.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :blog_id,
    :title,
    :body_html,
    :excerpt,
    :status,
    :author_name,
    :tags,
    :image_url,
    :url,
    :published_at,
    :updated_at,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      blog_id: fields["blog_id"],
      title: fields["title"],
      body_html: fields["body_html"],
      excerpt: fields["excerpt"],
      status: fields["status"],
      author_name: fields["author_name"],
      tags: fields["tags"] || [],
      image_url: fields["image_url"],
      url: fields["url"],
      published_at: Model.datetime(fields["published_at"]),
      updated_at: Model.datetime(fields["updated_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.RemoteProduct do
  @moduledoc """
  A product on a connected store.

  `price` is the lowest variant price, as a decimal string; `status` is
  `"active"`, `"draft"` or `"archived"`.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :title,
    :handle,
    :status,
    :description,
    :vendor,
    :product_type,
    :tags,
    :image_url,
    :url,
    :price,
    :currency,
    :updated_at,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      title: fields["title"],
      handle: fields["handle"],
      status: fields["status"],
      description: fields["description"],
      vendor: fields["vendor"],
      product_type: fields["product_type"],
      tags: fields["tags"] || [],
      image_url: fields["image_url"],
      url: fields["url"],
      price: fields["price"],
      currency: fields["currency"],
      updated_at: Model.datetime(fields["updated_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end
