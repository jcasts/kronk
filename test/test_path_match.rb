require 'test/test_helper'

class TestPathMatch < Test::Unit::TestCase

  def setup
    @pmatch = Kronk::Path::PathMatch.new %w{path to resource}
    @pmatch.matches = %w{this is 4 foo}
  end


  def test_make_path
    path = @pmatch.make_path "/%3/2/path/%4_%1"
    assert_equal %w{4 2 path foo_this}, path
  end


  def test_make_path_bad_token
    path = @pmatch.make_path "/%%3/2/path/%4_%1"
    assert_equal %w{4 2 path foo_this}, path
  end


  def test_make_path_escape
    path = @pmatch.make_path "/\\%3/2\\/path/%4_%1"
    assert_equal %w{%3 2/path foo_this}, path

    path = @pmatch.make_path "/\\\\%3/2/path/%4_%1/bar"
    assert_equal %w{\4 2 path foo_this bar}, path
  end


  def test_make_path_escape_token_num
    path = @pmatch.make_path "/%3\\1/2/path/%4_%1"
    assert_equal %w{41 2 path foo_this}, path

    path = @pmatch.make_path "/%\\31/2/path/%4_%1"
    assert_equal %w{31 2 path foo_this}, path
  end


  def test_make_path_bad_token_num
    path = @pmatch.make_path "/%31/2/path/%4_%1"
    assert_equal ["", "2", "path", "foo_this"], path
  end
end
