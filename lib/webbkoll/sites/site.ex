defmodule Webbkoll.Sites.Site do
  defstruct [
    :input_url,
    :final_url,
    :try_count,
    :status,
    :status_message,
    :data,
    :inserted_at,
    :updated_at
  ]
end
