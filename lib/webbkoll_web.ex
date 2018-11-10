defmodule WebbkollWeb do
  @moduledoc """
  A module that keeps using definitions for controllers,
  views and so on.

  This can be used in your application as:

      use WebbkollWeb, :controller
      use WebbkollWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: WebbkollWeb

      alias WebbkollWeb.Router.Helpers, as: Routes
      import WebbkollWeb.Gettext
      import Webbkoll.Helpers
    end
  end

  def view do
    quote do
      use Phoenix.View, root: "lib/webbkoll_web/templates", namespace: WebbkollWeb

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_csrf_token: 0, get_flash: 2, view_module: 1]

      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      alias WebbkollWeb.Router.Helpers, as: Routes
      import WebbkollWeb.ErrorHelpers
      import WebbkollWeb.Gettext
      import Webbkoll.Helpers
    end
  end

  def router do
    quote do
      use Phoenix.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel

      import WebbkollWeb.Gettext
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
