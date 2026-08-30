defmodule FoPost.BulkResult do
  @moduledoc """
  How many posts a bulk action changed.
  """

  alias FoPost.Model

  defstruct [:updated, :action, :mode, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      updated: fields["updated"],
      action: fields["action"],
      mode: fields["mode"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.BulkImportRow do
  @moduledoc """
  One CSV row as the bulk-import validator read it.
  """

  alias FoPost.Model

  defstruct [
    :row,
    :content_preview,
    :schedule_at,
    :labels,
    :has_media,
    :raw,
    accounts: [],
    errors: []
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      row: fields["row"],
      content_preview: fields["content_preview"],
      schedule_at: Model.datetime(fields["schedule_at"]),
      accounts: List.wrap(fields["accounts"]),
      labels: fields["labels"],
      has_media: fields["has_media"],
      errors: List.wrap(fields["errors"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.BulkImportValidation do
  @moduledoc """
  The dry run of a CSV import: what would be created, and what would not.
  """

  alias FoPost.BulkImportRow
  alias FoPost.Model

  defstruct [:total_rows, :valid_rows, :invalid_rows, :raw, rows: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      total_rows: fields["total_rows"],
      valid_rows: fields["valid_rows"],
      invalid_rows: fields["invalid_rows"],
      rows: Model.list(BulkImportRow, fields["rows"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.BulkImportResult do
  @moduledoc """
  What a committed CSV import created. Keep `:batch_id` to roll the batch back.
  """

  alias FoPost.Model

  defstruct [:batch_id, :created, :raw, posts: []]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      batch_id: fields["batch_id"],
      created: fields["created"],
      posts: Model.maps(fields["posts"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end
