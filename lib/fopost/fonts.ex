defmodule FoPost.Fonts do
  @moduledoc """
  Fonts for designs: the built-in library, plus font files a workspace uploads.

      {:ok, font} =
        FoPost.Fonts.upload(client,
          workspace_id: workspace.id,
          file: "Brand-Bold.woff2",
          family: "Brand",
          weight: 700
        )

  A file is a path, a `{filename, content}` tuple, or a map of `:filename`, `:content`,
  and optionally `:content_type`. Every function needs the `posts` scope and the
  workspace's create access.
  """

  alias FoPost.Client
  alias FoPost.Font
  alias FoPost.FontList
  alias FoPost.Result

  @content_types %{
    ".ttf" => "font/ttf",
    ".otf" => "font/otf",
    ".woff" => "font/woff",
    ".woff2" => "font/woff2"
  }

  @doc """
  The built-in font library, plus the workspace's uploaded fonts when `workspace_id` is
  given.
  """
  @spec list(Client.t(), String.t() | nil) :: {:ok, FontList.t()} | {:error, FoPost.Error.t()}
  def list(client, workspace_id \\ nil) do
    params = if workspace_id, do: [{"workspace_id", workspace_id}], else: []

    with {:ok, data} <- Client.request(client, :get, "/fonts", params: params) do
      {:ok, FontList.from_map(data)}
    end
  end

  @doc """
  Uploads one font file, up to 5 MB.

  Required: `:workspace_id`, `:file`. Optional: `:family` (defaults to the file name),
  `:weight` (`100` to `1000`, default `400`), `:style` (`"normal"` or `"italic"`).
  """
  @spec upload(Client.t(), keyword()) :: {:ok, Font.t()} | {:error, FoPost.Error.t()}
  def upload(client, opts) do
    fields =
      for key <- [:workspace_id, :family, :weight, :style],
          value = Keyword.get(opts, key),
          value != nil,
          do: {key, to_string(value)}

    form = fields ++ [file: part(Keyword.fetch!(opts, :file))]

    with {:ok, data} <- Client.request(client, :post, "/fonts", form_multipart: form) do
      {:ok, Font.from_map(data)}
    end
  end

  @doc """
  Deletes an uploaded font.
  """
  @spec delete(Client.t(), String.t()) :: :ok | {:error, FoPost.Error.t()}
  def delete(client, id) do
    path = "/fonts/" <> URI.encode(to_string(id), &URI.char_unreserved?/1)

    with {:ok, _body} <- Client.request(client, :delete, path) do
      :ok
    end
  end

  @doc "Same as `list/2`, but raises `FoPost.Error`."
  def list!(client, workspace_id \\ nil), do: Result.unwrap!(list(client, workspace_id))

  @doc "Same as `upload/2`, but raises `FoPost.Error`."
  def upload!(client, opts), do: Result.unwrap!(upload(client, opts))

  @doc "Same as `delete/2`, but raises `FoPost.Error`."
  def delete!(client, id), do: Result.unwrap!(delete(client, id))

  defp part(path) when is_binary(path) do
    filename = Path.basename(path)

    {File.read!(path), [filename: filename, content_type: content_type(filename)]}
  end

  defp part({filename, content}) do
    {content, [filename: filename, content_type: content_type(filename)]}
  end

  defp part(%{} = file) do
    filename = Map.get(file, :filename) || "font"
    content_type = Map.get(file, :content_type) || content_type(filename)

    {Map.fetch!(file, :content), [filename: filename, content_type: content_type]}
  end

  defp content_type(filename) do
    Map.get(@content_types, String.downcase(Path.extname(filename)), "application/octet-stream")
  end
end
