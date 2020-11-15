defmodule Webbkoll.Sites.Site do
  @derive Jason.Encoder

  defstruct [
    :id,
    :input_url,
    :try_count,
    :status,
    :status_message,
    :data,
    :inserted_at,
    :updated_at
  ]
end
