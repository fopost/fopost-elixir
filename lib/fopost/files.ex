defmodule FoPost.Files do
  @moduledoc false

  # The file shapes the SDK accepts on an upload or a post, resolved to one description:
  # a path (streamed, never read whole) or in-memory bytes, plus name, type, and size.

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

  @chunk 1_048_576

  @type t :: %{
          filename: String.t(),
          mime_type: String.t(),
          size: non_neg_integer(),
          path: String.t() | nil,
          data: binary() | nil
        }

  @spec describe(String.t() | map()) :: t()
  def describe(path) when is_binary(path) do
    describe(%{path: path})
  end

  def describe(%{} = file) do
    path = Map.get(file, :path)
    data = Map.get(file, :data)
    filename = Map.get(file, :filename) || (path && Path.basename(path)) || "upload"

    if is_nil(path) and is_nil(data) do
      raise ArgumentError, "FoPost: a file needs a :path or :data"
    end

    %{
      filename: filename,
      mime_type: Map.get(file, :mime_type) || content_type(filename),
      size: if(path, do: File.stat!(path).size, else: byte_size(data)),
      path: path,
      data: data
    }
  end

  @spec body(t()) :: binary() | File.Stream.t()
  def body(%{path: path}) when is_binary(path), do: chunked_stream(path)
  def body(%{data: data}), do: data

  # Elixir 1.16 swapped File.stream!'s arguments; 1.15 reads the second as modes.
  if Version.match?(System.version(), ">= 1.16.0") do
    defp chunked_stream(path), do: File.stream!(path, @chunk)
  else
    defp chunked_stream(path), do: File.stream!(path, [], @chunk)
  end

  @spec part(t()) :: {binary() | File.Stream.t(), keyword()}
  def part(file) do
    {body(file), [filename: file.filename, content_type: file.mime_type]}
  end

  @spec media_type(String.t()) :: String.t()
  def media_type("image/gif"), do: "gif"
  def media_type("video/" <> _rest), do: "video"
  def media_type(_mime_type), do: "image"

  @spec content_type(String.t()) :: String.t()
  def content_type(filename) do
    Map.get(@content_types, String.downcase(Path.extname(filename)), "application/octet-stream")
  end
end
