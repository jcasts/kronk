require 'test/test_helper'

class TestPath < Test::Unit::TestCase

  def test_parse_path_item_range
    assert_equal 1..4,   Kronk::Path.parse_path_item("1..4")
    assert_equal 1...4,  Kronk::Path.parse_path_item("1...4")
    assert_equal "1..4", Kronk::Path.parse_path_item("\\1..4")
    assert_equal "1..4", Kronk::Path.parse_path_item("1\\..4")
    assert_equal "1..4", Kronk::Path.parse_path_item("1.\\.4")
    assert_equal "1..4", Kronk::Path.parse_path_item("1..\\4")
    assert_equal "1..4", Kronk::Path.parse_path_item("1..4\\")
  end


  def test_parse_path_item_index_length
    assert_equal 2...6, Kronk::Path.parse_path_item("2,4")
    assert_equal "2,4", Kronk::Path.parse_path_item("\\2,4")
    assert_equal "2,4", Kronk::Path.parse_path_item("2\\,4")
    assert_equal "2,4", Kronk::Path.parse_path_item("2,\\4")
    assert_equal "2,4", Kronk::Path.parse_path_item("2,4\\")
  end


  def test_parse_path_item_anyval
    assert_equal Kronk::Path::ANY_VALUE, Kronk::Path.parse_path_item("*")
    assert_equal Kronk::Path::ANY_VALUE, Kronk::Path.parse_path_item("")
    assert_equal Kronk::Path::ANY_VALUE, Kronk::Path.parse_path_item("**?*?*?")
    assert_equal Kronk::Path::ANY_VALUE, Kronk::Path.parse_path_item(nil)
  end


  def test_parse_path_item_regex
    assert_equal /\A(test.*)\Z/,     Kronk::Path.parse_path_item("test*")
    assert_equal /\A(.?test.*)\Z/,   Kronk::Path.parse_path_item("?test*")
    assert_equal /\A(\?test.*)\Z/,   Kronk::Path.parse_path_item("\\?test*")
    assert_equal /\A(.?test\*.*)\Z/, Kronk::Path.parse_path_item("?test\\**")
    assert_equal /\A(.?test.*)\Z/,   Kronk::Path.parse_path_item("?test*?**??")
    assert_equal /\A(a|b)\Z/,        Kronk::Path.parse_path_item("a|b")
    assert_equal /\A(a|b(c|d))\Z/,   Kronk::Path.parse_path_item("a|b(c|d)")

    assert_equal /\A(a|b(c|d))\Z/i,
      Kronk::Path.parse_path_item("a|b(c|d)", Regexp::IGNORECASE)
  end


  def test_parse_path_item_string
    assert_equal "a|b", Kronk::Path.parse_path_item("a\\|b")
    assert_equal "a(b", Kronk::Path.parse_path_item("a\\(b")
    assert_equal "a?b", Kronk::Path.parse_path_item("a\\?b")
    assert_equal "a*b", Kronk::Path.parse_path_item("a\\*b")
  end


  def test_parse_path_item_passthru
    assert_equal Kronk::Path::PARENT,
      Kronk::Path.parse_path_item(Kronk::Path::PARENT)

    assert_equal :thing, Kronk::Path.parse_path_item(:thing)
  end


  def test_parse_path_str_simple
     assert_path %w{path to item}, "path/to/item"
     assert_path %w{path to item}, "///path//to/././item///"
     assert_path %w{path to item}, "///path//to/./item///"
     assert_path %w{path/to item}, "path\\/to/item"

     assert_path %w{path/to item/ i}, "path\\/to/item\\//i"

     assert_path [/\A(path\/\.to)\Z/i, /\A(item)\Z/i],
        "path\\/.to/item", Regexp::IGNORECASE

     assert_path ['path', /\A(to|for)\Z/, 'item'], "path/to|for/item"
  end


  def test_parse_path_str_value
     assert_path ['path', ['to', 'foo'], 'item'], "path/to=foo/item"
     assert_path ['path', [nil, 'foo'], 'item'],  "path/*=foo/item"
     assert_path ['path', [nil, 'foo'], 'item'],  "path/=foo/item"

     assert_path ['path', ['to', /\A(foo|bar)\Z/], 'item'],
       "path/to=foo|bar/item"

     assert_path [/\A(path)\Z/i, [/\A(to)\Z/i, /\A(foo)\Z/i], /\A(item)\Z/i],
       "path/to=foo/item", Regexp::IGNORECASE
  end


  def test_parse_path_str_recur
     assert_path ['path', ['to', 'foo', true], 'item'],    "path/**/to=foo/item"
     assert_path [['path', nil, true], 'to', 'item'],      "**/**/path/to/item"
     assert_path ['path', 'to', 'item', [nil, nil, true]], "path/to/item/**/**"
     assert_path ['path', [nil, 'foo', true], 'item'],     "path/**=foo/item"
  end


  def test_parse_path_str_parent
    assert_path ['path', PARENT, 'item'],              "path/../item"
    assert_path ['path', [PARENT, 'foo'], 'item'],     "path/..=foo/item"
    assert_path ['path', [nil, 'foo', true], 'item'],  "path/**/..=foo/item"
    assert_path ['path', [nil, 'foo', true], 'item'],  "path/**/=foo/item"
    assert_path ['path', ['item', nil, true]],         "path/**/../item"
    assert_path ['path', PARENT, ['item', nil, true]], "path/../**/item"
  end


  private

  PARENT = Kronk::Path::PARENT

  def assert_path match, path, regexp_opt=nil
    match.map! do |i|
      i = [i] unless Array === i
      i[0] ||= Kronk::Path::ANY_VALUE
      i[1] ||= Kronk::Path::ANY_VALUE
      i[2] ||= false
      i
    end

    assert_equal match, Kronk::Path.parse_path_str!(path, regexp_opt)
  end
end
