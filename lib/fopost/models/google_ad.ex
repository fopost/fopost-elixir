defmodule FoPost.GoogleBidStrategy do
  @moduledoc """
  A portfolio bid strategy on the account.
  """

  alias FoPost.Model

  defstruct [:id, :name, :type, :status, :campaign_count, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      type: fields["type"],
      status: fields["status"],
      campaign_count: fields["campaign_count"] || 0,
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.GoogleAdScheduleSlot do
  @moduledoc """
  One slot of a campaign's ad schedule.
  """

  alias FoPost.Model

  defstruct [:id, :day_of_week, :start_hour, :end_hour, :bid_modifier, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      day_of_week: fields["day_of_week"],
      start_hour: fields["start_hour"] || 0,
      end_hour: fields["end_hour"] || 0,
      bid_modifier: fields["bid_modifier"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.GoogleLocalServicesLead do
  @moduledoc """
  A lead from Local Services Ads, read live and never stored.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :category,
    :service,
    :contact_name,
    :phone,
    :email,
    :status,
    :type,
    :created_at,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      category: fields["category"],
      service: fields["service"],
      contact_name: fields["contact_name"],
      phone: fields["phone"],
      email: fields["email"],
      status: fields["status"],
      type: fields["type"],
      created_at: fields["created_at"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.GoogleConversionAction do
  @moduledoc """
  A conversion action on the account.
  """

  alias FoPost.Model

  defstruct [:id, :name, :category, :status, :type, :counting_type, :value_minor, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      category: fields["category"],
      status: fields["status"],
      type: fields["type"],
      counting_type: fields["counting_type"],
      value_minor: fields["value_minor"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end
