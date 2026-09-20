defmodule FoPost.WhatsappProfile do
  @moduledoc """
  The business profile on a WhatsApp number, plus how the platform rates it.

  `display_name_status` is the platform's review state for the display name: a
  name change is a request, and the number keeps the old one until it passes.
  """

  alias FoPost.Model

  defstruct [
    :about,
    :address,
    :description,
    :email,
    :vertical,
    :websites,
    :profile_picture_url,
    :display_name,
    :display_name_status,
    :username,
    :quality_rating,
    :messaging_limit_tier,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      about: fields["about"],
      address: fields["address"],
      description: fields["description"],
      email: fields["email"],
      vertical: fields["vertical"],
      websites: fields["websites"] || [],
      profile_picture_url: fields["profile_picture_url"],
      display_name: fields["display_name"],
      display_name_status: fields["display_name_status"],
      username: fields["username"],
      quality_rating: fields["quality_rating"],
      messaging_limit_tier: fields["messaging_limit_tier"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.WhatsappTemplate do
  @moduledoc """
  A message template. `status` is the review outcome the platform assigned;
  nothing marks a template approved but the platform.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :language,
    :category,
    :status,
    :rejected_reason,
    :components,
    :quality_score,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      language: fields["language"],
      category: fields["category"],
      status: fields["status"],
      rejected_reason: fields["rejected_reason"],
      components: fields["components"] || [],
      quality_score: fields["quality_score"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.WhatsappGroup do
  @moduledoc """
  A group on the business number. Participation is invite-only: no endpoint adds
  anyone, so `invite_link` is how they join.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :subject,
    :description,
    :participant_count,
    :invite_link,
    :created_at,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      subject: fields["subject"],
      description: fields["description"],
      participant_count: fields["participant_count"],
      invite_link: fields["invite_link"],
      created_at: Model.datetime(fields["created_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.WhatsappBlockResult do
  @moduledoc """
  What the platform took and what it refused.
  """

  alias FoPost.Model

  defstruct [:blocked, :unblocked, :failed, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      blocked: fields["blocked"] || [],
      unblocked: fields["unblocked"] || [],
      failed: fields["failed"] || [],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.WhatsappCommerceSettings do
  @moduledoc """
  Whether the cart and catalog show on the number, and which catalog is linked.
  """

  alias FoPost.Model

  defstruct [:cart_enabled, :catalog_visible, :catalog_id, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      cart_enabled: fields["cart_enabled"],
      catalog_visible: fields["catalog_visible"],
      catalog_id: fields["catalog_id"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.WhatsappFlow do
  @moduledoc """
  An in-chat form. The platform validates it and owns its status: `DRAFT`,
  `PUBLISHED`, `DEPRECATED` or `BLOCKED`.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :name,
    :status,
    :categories,
    :validation_errors,
    :endpoint_uri,
    :json_version,
    :preview_url,
    :preview_expires_at,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      name: fields["name"],
      status: fields["status"],
      categories: fields["categories"] || [],
      validation_errors: Model.maps(fields["validation_errors"]),
      endpoint_uri: fields["endpoint_uri"],
      json_version: fields["json_version"],
      preview_url: fields["preview_url"],
      preview_expires_at: Model.datetime(fields["preview_expires_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.WhatsappFlowJsonResult do
  @moduledoc """
  The platform's verdict on an uploaded definition. It answers with the errors
  rather than refusing the upload, so they arrive as data.
  """

  alias FoPost.Model

  defstruct [:success, :validation_errors, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      success: fields["success"] || false,
      validation_errors: Model.maps(fields["validation_errors"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.WhatsappFlowResponse do
  @moduledoc """
  What one person submitted through a flow.
  """

  alias FoPost.Model

  defstruct [:message_id, :wa_id, :flow_token, :answers, :responded_at, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      message_id: fields["message_id"],
      wa_id: fields["wa_id"],
      flow_token: fields["flow_token"],
      answers: fields["answers"] || %{},
      responded_at: Model.datetime(fields["responded_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.WhatsappEncryptionKeyStatus do
  @moduledoc """
  Whether a business public key is registered. The key itself never comes back.
  """

  alias FoPost.Model

  defstruct [:has_key, :signature_status, :raw]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      has_key: fields["has_key"] || false,
      signature_status: fields["signature_status"],
      raw: data
    }
  end

  def from_map(_data), do: nil
end

defmodule FoPost.WhatsappSandboxSession do
  @moduledoc """
  A sandbox invitation. Only the last four digits of the tester's number travel;
  the number itself is never stored.
  """

  alias FoPost.Model

  defstruct [
    :id,
    :status,
    :phone_number_last4,
    :invited_at,
    :activated_at,
    :expires_at,
    :raw
  ]

  @type t :: %__MODULE__{}

  @doc false
  def from_map(data) when is_map(data) do
    fields = Model.normalize(data)

    %__MODULE__{
      id: fields["id"],
      status: fields["status"],
      phone_number_last4: fields["phone_number_last4"],
      invited_at: Model.datetime(fields["invited_at"]),
      activated_at: Model.datetime(fields["activated_at"]),
      expires_at: Model.datetime(fields["expires_at"]),
      raw: data
    }
  end

  def from_map(_data), do: nil
end
