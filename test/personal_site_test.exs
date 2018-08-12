defmodule PersonalSiteTest do
  use ExUnit.Case
  doctest PersonalSite

  test "greets the world" do
    assert PersonalSite.hello() == :world
  end
end
