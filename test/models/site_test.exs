defmodule Webbkoll.SiteTest do
  use Webbkoll.ModelCase

  alias Webbkoll.Site

  @valid_attrs %{data: %{}, input_url: "some content", session_id: "some content", status: "some content", status_message: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Site.changeset(%Site{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Site.changeset(%Site{}, @invalid_attrs)
    refute changeset.valid?
  end
end
