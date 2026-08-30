defmodule FoPost.Media do
  @moduledoc """
  The media library.

  Uploads count against the plan's storage allowance and are reachable with the `posts`
  scope. Up to five files per call, 50 MB each; the API verifies the bytes against the
  declared type.

      {:ok, [asset]} =
        FoPost.Media.upload(client, workspace_id: workspace.id, files: ["chart.png"])

      FoPost.Posts.create(client,
        workspace_id: workspace.id,
        accounts: [account.id],
        content: %{text: "The numbers", media: [FoPost.MediaAsset.to_media_item(asset)]}
      )

  A file is a path, a `{filename, content}` tuple, or a map of `:filename`, `:content`,
  and optionally `:content_type`.
  """

  alias FoPost.Client
  alias FoPost.MediaAsset
  alias FoPost.Message
  alias FoPost.Model
  alias FoPost.Result

  @content_types %{
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".png" => "image/png",
    ".gif" => "image/gif",
    ".webp" => "image/webp",
    ".mp4" => "video/mp4",
    ".mov" => "video/quicktime",
    ".webm" => "video/webm",
    ".pdf" => "application/pdf",
    ".txt" => "text/plain",
    ".csv" => "text/csv"
  }

  @doc """
  A workspace's media library. `:workspace_id` is required.
  """
  @spec list(Client.t(), keyword()) :: {:ok, [MediaAsset.t()]} | {:error, FoPost.Error.t()}
  def list(client, opts \\ []) do
    params = Model.take_params(opts, [{:workspace_id, "workspaceId"}])

    with {:ok, data} <- Client.request(client, :get, "/media", params: params) do
      {:ok, Model.list(MediaAsset, data)}
    end
  end

  @doc """
  Stores files in the media library.

  Required: `:files`. Pass `:workspace_id` to save them to that workspace's library.
  """
  @spec upload(Client.t(), keyword()) :: {:ok, [MediaAsset.t()]} | {:error, FoPost.Error.t()}
  def upload(client, opts) do
    parts =
      opts
      |> Keyword.fetch!(:files)
      |> List.wrap()
      |> Enum.map(fn file -> {:files, part(file)} end)

    form = workspace_field(opts) ++ parts

    with {:ok, data} <- Client.request(client, :post, "/media/upload", form_multipart: form) do
      {:ok, Model.list(MediaAsset, data)}
    end
  end

  @doc """
  Removes an asset from the library.
  """
  @spec delete(Client.t(), String.t()) :: {:ok, Message.t()} | {:error, FoPost.Error.t()}
  def delete(client, id) do
    path = "/media/" <> URI.encode(to_string(id), &URI.char_unreserved?/1)

    with {:ok, data} <- Client.request(client, :delete, path) do
      {:ok, Message.from_map(data)}
    end
  end

  @doc "Same as `list/2`, but raises `FoPost.Error`."
  def list!(client, opts \\ []), do: Result.unwrap!(list(client, opts))

  @doc "Same as `upload/2`, but raises `FoPost.Error`."
  def upload!(client, opts), do: Result.unwrap!(upload(client, opts))

  @doc "Same as `delete/2`, but raises `FoPost.Error`."
  def delete!(client, id), do: Result.unwrap!(delete(client, id))

  defp workspace_field(opts) do
    case Keyword.get(opts, :workspace_id) do
      nil -> []
      workspace_id -> [{:workspaceId, workspace_id}]
    end
  end

  defp part(path) when is_binary(path) do
    filename = Path.basename(path)

    {File.read!(path), [filename: filename, content_type: content_type(filename)]}
  end

  defp part({filename, content}) do
    {content, [filename: filename, content_type: content_type(filename)]}
  end

  defp part(%{} = file) do
    filename = Map.get(file, :filename) || "upload"
    content_type = Map.get(file, :content_type) || content_type(filename)

    {Map.fetch!(file, :content), [filename: filename, content_type: content_type]}
  end

  defp content_type(filename) do
    Map.get(@content_types, String.downcase(Path.extname(filename)), "application/octet-stream")
  end
end
