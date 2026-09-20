defmodule FoPost.ContactChannel do
  @moduledoc """
  One handle on one network.

  `:handle` is lower-cased with no leading `@`. `:external_id` is the
  platform's own id for that person when it gave one, and a merge prefers it:
  a handle can be changed, an id cannot.
  """

  alias FoPost.Model

  defstruct [:platform, :handle, :external_id, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      platform: fields["platform"],
      handle: fields["handle"],
      external_id: fields["external_id"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.Contact do
  @moduledoc """
  One person behind the inbox, however many handles they write from.

  Built from what already reached the workspace: an inbound item files its
  author, a reply files whoever you answered, an import files a row.
  `:source` is `"inbox"`, `"radar"` or `"import"` — what first created it.
  """

  alias FoPost.ContactChannel
  alias FoPost.Model

  defstruct [
    :id,
    :display_name,
    :channels,
    :source,
    :note,
    :first_seen_at,
    :last_seen_at,
    :fields,
    :labels,
    :workspace_id,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      display_name: fields["display_name"],
      channels: Model.list(ContactChannel, fields["channels"]),
      source: fields["source"],
      note: fields["note"],
      first_seen_at: Model.datetime(fields["first_seen_at"]),
      last_seen_at: Model.datetime(fields["last_seen_at"]),
      fields: Model.normalize(fields["fields"]),
      labels: Model.maps(fields["labels"]),
      workspace_id: fields["workspace_id"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.ContactField do
  @moduledoc """
  A column the workspace invented.

  `:key` is the machine name and also the CSV column header, fixed once
  created; `:name` is what people read. `:type` is `"text"`, `"number"`,
  `"date"`, `"select"` or `"boolean"`.
  """

  alias FoPost.Model

  defstruct [:id, :key, :name, :type, :options, :position, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      key: fields["key"],
      name: fields["name"],
      type: fields["type"],
      options: List.wrap(fields["options"]),
      position: fields["position"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.ContactConversation do
  @moduledoc """
  One inbox thread a contact appears in.

  `:key` is how the inbox groups it: the DM thread id, else the post the
  comments hang off, else the handle.
  """

  alias FoPost.Model

  defstruct [
    :key,
    :account_id,
    :account_username,
    :platform,
    :messages,
    :received,
    :sent,
    :last_message_at,
    :last_item_id,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      key: fields["key"],
      account_id: fields["account_id"],
      account_username: fields["account_username"],
      platform: fields["platform"],
      messages: fields["messages"],
      received: fields["received"],
      sent: fields["sent"],
      last_message_at: Model.datetime(fields["last_message_at"]),
      last_item_id: fields["last_item_id"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.ContactImportResult do
  @moduledoc """
  What an import did.

  `:unknown_columns` are headers matching no custom field. They are reported
  rather than stored, so a typo in a column name is visible.
  """

  alias FoPost.Model

  defstruct [:created, :merged, :skipped, :unknown_columns, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      created: fields["created"],
      merged: fields["merged"],
      skipped: Model.maps(fields["skipped"]),
      unknown_columns: List.wrap(fields["unknown_columns"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.ConversationAnalyticsRow do
  @moduledoc """
  How one thread performed over the period.

  `:key` is an opaque, stable handle for the thread, not the id or handle the
  inbox groups on: that would be a person, and this reads under the
  `analytics` scope. Use it to line the same thread up between two calls.
  """

  alias FoPost.Model

  defstruct [
    :key,
    :account_id,
    :platform,
    :received,
    :sent,
    :answered,
    :open,
    :median_response_minutes,
    :first_message_at,
    :last_message_at,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      key: fields["key"],
      account_id: fields["account_id"],
      platform: fields["platform"],
      received: fields["received"],
      sent: fields["sent"],
      answered: fields["answered"],
      open: fields["open"],
      median_response_minutes: fields["median_response_minutes"],
      first_message_at: Model.datetime(fields["first_message_at"]),
      last_message_at: Model.datetime(fields["last_message_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.ConversationAnalytics do
  @moduledoc """
  One page of per-thread inbox numbers.
  """

  alias FoPost.ConversationAnalyticsRow
  alias FoPost.Model

  defstruct [:conversations, :total, :page, :per_page, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      conversations: Model.list(ConversationAnalyticsRow, fields["conversations"]),
      total: fields["total"],
      page: fields["page"],
      per_page: fields["per_page"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end
