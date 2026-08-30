defmodule FoPost.PageMeta do
  @moduledoc """
  Pagination counters that travel alongside a paginated list.
  """

  alias FoPost.Model

  defstruct [:current_page, :per_page, :total, :last_page, :from, :to, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      current_page: fields["current_page"],
      per_page: fields["per_page"],
      total: fields["total"],
      last_page: fields["last_page"],
      from: fields["from"],
      to: fields["to"],
      raw: data
    }
  end

  def from_map(_data), do: %__MODULE__{}
end

defmodule FoPost.Page do
  @moduledoc """
  One page of a paginated list: the rows on `:data`, the counters on `:meta`.

  `FoPost.Posts.stream/2` walks every page for you when you do not want to page by hand.
  """

  alias FoPost.Model
  alias FoPost.PageMeta

  defstruct data: [], meta: %PageMeta{}

  @type t :: %__MODULE__{data: list(), meta: PageMeta.t()}

  @doc false
  def from_map(body, module) when is_map(body) do
    %__MODULE__{
      data: Model.list(module, Map.get(body, "data")),
      meta: PageMeta.from_map(Map.get(body, "meta"))
    }
  end

  def from_map(_body, _module), do: %__MODULE__{}
end
