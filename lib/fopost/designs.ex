defmodule FoPost.Designs do
  @moduledoc """
  Designs: stories, posts, carousels, thumbnails, cards, and collages built in the editor.

      {:ok, design} =
        FoPost.Designs.create(client, workspace_id: workspace.id, kind: "post", name: "Launch")

      {:ok, export} = FoPost.Designs.export(client, design.id, format: "png")
      [file | _] = export.files

  The document is passed through as a plain map with string keys: read it from
  `design.document`, change it, and send it back with `update/3`. Every function needs
  the `posts` scope and the workspace's create access; `text_to_slides/2` spends AI
  balance and also needs the `ai` scope.
  """

  alias FoPost.Client
  alias FoPost.Design
  alias FoPost.DesignChange
  alias FoPost.DesignDeletion
  alias FoPost.DesignExport
  alias FoPost.DesignPost
  alias FoPost.DesignVersion
  alias FoPost.Model
  alias FoPost.Result
  alias FoPost.SlideOutline

  @doc """
  A workspace's designs, newest first, without their documents.

  Options: `:kind` (`"story"`, `"post"`, `"carousel"`, `"thumbnail"`, `"card"`,
  `"collage"`), `:limit`, `:offset`.
  """
  @spec list(Client.t(), String.t(), keyword()) ::
          {:ok, [Design.t()]} | {:error, FoPost.Error.t()}
  def list(client, workspace_id, opts \\ []) do
    params = [{"workspace_id", workspace_id} | Model.take_params(opts, [:kind, :limit, :offset])]

    with {:ok, data} <- Client.request(client, :get, "/designs", params: params) do
      {:ok, Model.list(Design, data)}
    end
  end

  @doc """
  Creates a design.

  Required: `:workspace_id`, `:kind`. Optional: `:name`, `:document`, `:brand_voice_id`
  to start from that brand's style.
  """
  @spec create(Client.t(), keyword()) :: {:ok, Design.t()} | {:error, FoPost.Error.t()}
  def create(client, opts) do
    body = Model.take_body(opts, [:workspace_id, :name, :kind, :document, :brand_voice_id])

    with {:ok, data} <- Client.request(client, :post, "/designs", json: body) do
      {:ok, Design.from_map(data)}
    end
  end

  @doc """
  One design, with its document.
  """
  @spec get(Client.t(), String.t()) :: {:ok, Design.t()} | {:error, FoPost.Error.t()}
  def get(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id)) do
      {:ok, Design.from_map(data)}
    end
  end

  @doc """
  Edits a design. Only the keys you pass are sent.

  Options: `:name`, `:kind`, `:document`, `:create_version` (`true` saves a version with
  the change, returned on `:version`).
  """
  @spec update(Client.t(), String.t(), keyword()) ::
          {:ok, DesignChange.t()} | {:error, FoPost.Error.t()}
  def update(client, id, opts) do
    body = Model.take_body(opts, [:name, :kind, :document, :create_version])

    with {:ok, data} <- Client.request(client, :patch, path(id), json: body, unwrap: false) do
      {:ok, DesignChange.from_map(data)}
    end
  end

  @doc """
  Deletes a design.
  """
  @spec delete(Client.t(), String.t()) :: {:ok, DesignDeletion.t()} | {:error, FoPost.Error.t()}
  def delete(client, id) do
    with {:ok, data} <- Client.request(client, :delete, path(id)) do
      {:ok, DesignDeletion.from_map(data)}
    end
  end

  @doc """
  A design's saved versions, newest first. Pass `include_document: true` to get each
  version's document too.
  """
  @spec versions(Client.t(), String.t(), keyword()) ::
          {:ok, [DesignVersion.t()]} | {:error, FoPost.Error.t()}
  def versions(client, id, opts \\ []) do
    params = if Keyword.get(opts, :include_document), do: [{"include", "document"}], else: []

    with {:ok, data} <- Client.request(client, :get, path(id, "versions"), params: params) do
      {:ok, Model.list(DesignVersion, data)}
    end
  end

  @doc """
  Puts a saved version's document back on the design.
  """
  @spec restore_version(Client.t(), String.t(), String.t()) ::
          {:ok, DesignChange.t()} | {:error, FoPost.Error.t()}
  def restore_version(client, id, version_id) do
    url = path(id, "versions/" <> encode(version_id) <> "/restore")

    with {:ok, data} <- Client.request(client, :post, url, unwrap: false) do
      {:ok, DesignChange.from_map(data)}
    end
  end

  @doc """
  Copies a design. Optional: `:name` for the copy.
  """
  @spec duplicate(Client.t(), String.t(), keyword()) ::
          {:ok, Design.t()} | {:error, FoPost.Error.t()}
  def duplicate(client, id, opts \\ []) do
    body = Model.take_body(opts, [:name])

    with {:ok, data} <- Client.request(client, :post, path(id, "duplicate"), json: body) do
      {:ok, Design.from_map(data)}
    end
  end

  @doc """
  Renders a design into the media library.

  Required: `:format` (`"png"`, `"jpg"`, `"pdf"`, `"mp4"`, `"gif"`). Optional:
  `:page_indexes` to export only those pages, `:duration_sec` (`5`, `10`, or `15`) for
  an animated format.
  """
  @spec export(Client.t(), String.t(), keyword()) ::
          {:ok, DesignExport.t()} | {:error, FoPost.Error.t()}
  def export(client, id, opts) do
    body = Model.take_body(opts, [:format, :page_indexes, :duration_sec])

    with {:ok, data} <- Client.request(client, :post, path(id, "export"), json: body) do
      {:ok, DesignExport.from_map(data)}
    end
  end

  @doc """
  Creates one design per row from a template design, filling its fields from each row.

  Required: `:rows`, a list of maps from field name to value. Optional: `:name_column`,
  the field that names each new design.
  """
  @spec bulk(Client.t(), String.t(), keyword()) ::
          {:ok, [Design.t()]} | {:error, FoPost.Error.t()}
  def bulk(client, id, opts) do
    body = Model.take_body(opts, [:rows, :name_column])

    with {:ok, data} <- Client.request(client, :post, path(id, "bulk"), json: body) do
      {:ok, Model.list(Design, data)}
    end
  end

  @doc """
  The posts that used a design, with their engagement and views.
  """
  @spec posts(Client.t(), String.t()) :: {:ok, [DesignPost.t()]} | {:error, FoPost.Error.t()}
  def posts(client, id) do
    with {:ok, data} <- Client.request(client, :get, path(id, "posts")) do
      {:ok, Model.list(DesignPost, data)}
    end
  end

  @doc """
  Splits text into a carousel outline: a cover, the slides, and a closing call to action.
  Spends AI balance and needs the `ai` scope.

  Required: `:workspace_id` and one of `:text` or `:post_id`. Optional: `:max_slides`,
  `:brand_voice_id`.
  """
  @spec text_to_slides(Client.t(), keyword()) ::
          {:ok, SlideOutline.t()} | {:error, FoPost.Error.t()}
  def text_to_slides(client, opts) do
    body = Model.take_body(opts, [:workspace_id, :text, :post_id, :max_slides, :brand_voice_id])

    with {:ok, data} <- Client.request(client, :post, "/designs/text-to-slides", json: body) do
      {:ok, SlideOutline.from_map(data)}
    end
  end

  @doc """
  Creates a design from a post's text, or from text given directly.

  Required: `:workspace_id` and one of `:text` or `:post_id`. Optional: `:style`
  (`"quote"`, `"post"`, `"plain"`), `:preset`, `:account_id` to size it for that
  account's network, `:carousel`, `:name`, `:brand_voice_id`.
  """
  @spec from_post(Client.t(), keyword()) :: {:ok, Design.t()} | {:error, FoPost.Error.t()}
  def from_post(client, opts) do
    body =
      Model.take_body(opts, [
        :workspace_id,
        :text,
        :post_id,
        :style,
        :preset,
        :account_id,
        :carousel,
        :name,
        :brand_voice_id
      ])

    with {:ok, data} <- Client.request(client, :post, "/designs/from-post", json: body) do
      {:ok, Design.from_map(data)}
    end
  end

  @doc "Same as `list/3`, but raises `FoPost.Error`."
  def list!(client, workspace_id, opts \\ []),
    do: Result.unwrap!(list(client, workspace_id, opts))

  @doc "Same as `create/2`, but raises `FoPost.Error`."
  def create!(client, opts), do: Result.unwrap!(create(client, opts))

  @doc "Same as `get/2`, but raises `FoPost.Error`."
  def get!(client, id), do: Result.unwrap!(get(client, id))

  @doc "Same as `update/3`, but raises `FoPost.Error`."
  def update!(client, id, opts), do: Result.unwrap!(update(client, id, opts))

  @doc "Same as `delete/2`, but raises `FoPost.Error`."
  def delete!(client, id), do: Result.unwrap!(delete(client, id))

  @doc "Same as `versions/3`, but raises `FoPost.Error`."
  def versions!(client, id, opts \\ []), do: Result.unwrap!(versions(client, id, opts))

  @doc "Same as `restore_version/3`, but raises `FoPost.Error`."
  def restore_version!(client, id, version_id) do
    Result.unwrap!(restore_version(client, id, version_id))
  end

  @doc "Same as `duplicate/3`, but raises `FoPost.Error`."
  def duplicate!(client, id, opts \\ []), do: Result.unwrap!(duplicate(client, id, opts))

  @doc "Same as `export/3`, but raises `FoPost.Error`."
  def export!(client, id, opts), do: Result.unwrap!(export(client, id, opts))

  @doc "Same as `bulk/3`, but raises `FoPost.Error`."
  def bulk!(client, id, opts), do: Result.unwrap!(bulk(client, id, opts))

  @doc "Same as `posts/2`, but raises `FoPost.Error`."
  def posts!(client, id), do: Result.unwrap!(posts(client, id))

  @doc "Same as `text_to_slides/2`, but raises `FoPost.Error`."
  def text_to_slides!(client, opts), do: Result.unwrap!(text_to_slides(client, opts))

  @doc "Same as `from_post/2`, but raises `FoPost.Error`."
  def from_post!(client, opts), do: Result.unwrap!(from_post(client, opts))

  defp path(id), do: "/designs/" <> encode(id)
  defp path(id, suffix), do: path(id) <> "/" <> suffix

  defp encode(value), do: URI.encode(to_string(value), &URI.char_unreserved?/1)
end
