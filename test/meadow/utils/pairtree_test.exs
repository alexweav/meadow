defmodule Meadow.Utils.PairtreeTest do
  use ExUnit.Case
  alias Meadow.Utils.Pairtree

  describe "generate/2" do
    test "full length" do
      assert Pairtree.generate("ABCDEFGH") == {:ok, "ab/cd/ef/gh/abcdefgh"}
    end

    test "odd number of characters" do
      assert Pairtree.generate("ABCDEFG") == {:ok, "ab/cd/ef/abcdefg"}
    end

    test "partial" do
      assert Pairtree.generate("ABCDEFGH", 3) == {:ok, "ab/cd/ef/abcdefgh"}
    end

    test "too short for partial" do
      assert Pairtree.generate("ABCDEFGH", 8) == {:ok, "ab/cd/ef/gh/abcdefgh"}
    end

    test "bad length" do
      assert Pairtree.generate("ABCDEFGH", "foo") == {:error, "length must be nil or integer"}
    end
  end

  describe "generate!/2" do
    test "full length" do
      assert Pairtree.generate!("ABCDEFGH") == "ab/cd/ef/gh/abcdefgh"
    end

    test "odd number of characters" do
      assert Pairtree.generate!("ABCDEFG") == "ab/cd/ef/abcdefg"
    end

    test "partial" do
      assert Pairtree.generate!("ABCDEFGH", 3) == "ab/cd/ef/abcdefgh"
    end

    test "too short for partial" do
      assert Pairtree.generate!("ABCDEFGH", 8) == "ab/cd/ef/gh/abcdefgh"
    end

    test "bad length" do
      assert_raise ArgumentError, "length must be nil or integer", fn ->
        Pairtree.generate!("ABCDEFGH", "foo")
      end
    end
  end

  describe "generate_pyramid_path/1" do
    assert Pairtree.generate_pyramid_path("01DT5BNAR8XB6YFWB9V1VQQKDN") ==
             "01/dt/5b/na/r8/xb/6y/fw/b9/v1/vq/qk/dn-pyramid.tif"
  end
end
