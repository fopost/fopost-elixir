defmodule FoPost.Media do
  @moduledoc """
  The media library.

  Uploads count against the plan's storage allowance and are reachable with the `posts`
  scope. Up to five files per call; the API verifies the bytes against the declared type.
  `limits/2` tells how large a file the account may upload and how much a multipart
  request may carry per file — anything bigger goes through a direct upload.

      {:ok, [asset]} =
        FoPost.Media.upload(client, workspace_id: workspace.id, files: ["chart.png"])

      FoPost.Posts.create(client,
        workspace_id: workspace.id,
        accounts: [account.id],
        content: %{text: "The numbers", media: [FoPost.MediaAsset.to_media_item(asset)]}
      )

  A file is a path, a `{filename, content}` tuple, or a map of `:filename`, `:content`,
  and optionally `:content_type`.

  A direct upload skips the API for the bytes themselves: `presign/2` issues a one-time
  URL, the file is `PUT` there, and `complete/2` files it in the library.
  `upload_direct/6` does all three, and streams a file given as `{:file, path}` instead of
  holding it in memory.

      {:ok, asset} =
        FoPost.Media.upload_direct(client, workspace.id, "clip.mp4", "video/mp4", {:file, path})
  """

  alias FoPost.Client
  alias FoPost.Files
  alias FoPost.MediaAsset
  alias FoPost.Message
  alias FoPost.Model
  alias FoPost.PresignedUpload
  alias FoPost.Result
  alias FoPost.UploadLimits

  @presign_fields [
    {:workspace_id, "workspaceId"},
    :filename,
    {:mime_type, "mimeType"},
    :size,
    {:folder_id, "folderId"},
    :origin,
    {:brand_role, "brandRole"},
    {:brand_voice_id, "brandVoiceId"},
    {:person_consent, "personConsent"}
  ]

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
  What the account may upload: the largest file by any route, the multipart ceiling per
  file, the files per call, and the accepted types.
  """
  @spec limits(Client.t(), String.t() | nil) ::
          {:ok, UploadLimits.t()} | {:error, FoPost.Error.t()}
  def limits(client, workspace_id \\ nil) do
    params = Model.take_params([workspace_id: workspace_id], [{:workspace_id, "workspaceId"}])

    with {:ok, data} <- Client.request(client, :get, "/media/limits", params: params) do
      {:ok, UploadLimits.from_map(data)}
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
  Issues a presigned URL for a direct upload.

  Required: `:workspace_id`, `:filename`, `:mime_type`, and `:size` in bytes, up to the
  account's `limits/2`. Optional: `:folder_id`, `:origin`, `:brand_role`, `:brand_voice_id`,
  `:person_consent` (a map of `subject` and `statement`, required for a `"person"` role).
  """
  @spec presign(Client.t(), keyword()) ::
          {:ok, PresignedUpload.t()} | {:error, FoPost.Error.t()}
  def presign(client, opts) do
    body = Model.take_body(opts, @presign_fields)

    with {:ok, data} <- Client.request(client, :post, "/media/presign", json: body) do
      {:ok, PresignedUpload.from_map(data)}
    end
  end

  @doc """
  Files a direct upload in the library once its bytes have been `PUT` to the presigned URL.
  """
  @spec complete(Client.t(), String.t()) :: {:ok, MediaAsset.t()} | {:error, FoPost.Error.t()}
  def complete(client, upload_id) do
    id = URI.encode(to_string(upload_id), &URI.char_unreserved?/1)

    with {:ok, data} <- Client.request(client, :post, "/media/presign/" <> id <> "/complete") do
      {:ok, MediaAsset.from_map(data)}
    end
  end

  @doc """
  Presigns, uploads the bytes with the issued headers and no API key, then completes.

  `source` is the bytes as a binary, or `{:file, path}` to stream the file from disk.
  `opts` takes the optional `presign/2` fields.
  """
  @spec upload_direct(
          Client.t(),
          String.t(),
          String.t(),
          String.t(),
          binary() | {:file, Path.t()},
          keyword()
        ) :: {:ok, MediaAsset.t()} | {:error, FoPost.Error.t()}
  def upload_direct(client, workspace_id, filename, mime_type, source, opts \\ []) do
    file = Files.describe(Map.merge(%{filename: filename, mime_type: mime_type}, source(source)))

    presign_opts =
      Keyword.merge(opts,
        workspace_id: workspace_id,
        filename: filename,
        mime_type: mime_type,
        size: file.size
      )

    with {:ok, presigned} <- presign(client, presign_opts),
         {:ok, _body} <- put_bytes(client, presigned, file) do
      complete(client, presigned.upload_id)
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

  @doc "Same as `limits/2`, but raises `FoPost.Error`."
  def limits!(client, workspace_id \\ nil), do: Result.unwrap!(limits(client, workspace_id))

  @doc "Same as `upload/2`, but raises `FoPost.Error`."
  def upload!(client, opts), do: Result.unwrap!(upload(client, opts))

  @doc "Same as `presign/2`, but raises `FoPost.Error`."
  def presign!(client, opts), do: Result.unwrap!(presign(client, opts))

  @doc "Same as `complete/2`, but raises `FoPost.Error`."
  def complete!(client, upload_id), do: Result.unwrap!(complete(client, upload_id))

  @doc "Same as `upload_direct/6`, but raises `FoPost.Error`."
  def upload_direct!(client, workspace_id, filename, mime_type, source, opts \\ []) do
    Result.unwrap!(upload_direct(client, workspace_id, filename, mime_type, source, opts))
  end

  @doc "Same as `delete/2`, but raises `FoPost.Error`."
  def delete!(client, id), do: Result.unwrap!(delete(client, id))

  defp source({:file, path}), do: %{path: path}
  defp source(data) when is_binary(data), do: %{data: data}

  defp put_bytes(client, presigned, file) do
    headers = Map.put(presigned.headers, "content-length", Integer.to_string(file.size))

    Client.put_raw(client, presigned.upload_url, headers, Files.body(file))
  end

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

  defp content_type(filename), do: Files.content_type(filename)
end
