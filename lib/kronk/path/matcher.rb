##
# Path::Matcher is representation of a single node of a relative path used
# to find values in a data set.

class Kronk::Path::Matcher

  # Used as path item value to match any key or value.
  module ANY_VALUE; end

  # Shortcut characters that require modification before being turned into
  # a matcher.
  SUFF_CHARS = Regexp.escape "*?"

  # All special path characters.
  PATH_CHARS = Regexp.escape("()|") << SUFF_CHARS

  # Path chars that get regexp escaped.
  RESC_CHARS = "*?()|/"

  # Matcher for Range path item.
  RANGE_MATCHER  = %r{^(\-?\d+)(\.{2,3})(\-?\d+)$}

  # Matcher for index,length path item.
  ILEN_MATCHER   = %r{^(\-?\d+),(\-?\d+)$}

  # Matcher allowing any value to be matched.
  ANYVAL_MATCHER = /^(\?*\*+\?*)*$/

  # Matcher to assert if any unescaped special chars are in a path item.
  PATH_CHAR_MATCHER = /(^|[^#{Kronk::Path::RECH}])([#{PATH_CHARS}])/


  attr_reader :key, :value, :regex_opts

  def initialize opts={}
    @regex_opts = opts[:regex_opts]
    @recursive  = !!opts[:recursive]

    @key = parse_node opts[:key] if
      opts[:key] && !opts[:key].to_s.empty?

    @value = parse_node opts[:value] if
      opts[:value] && !opts[:value].to_s.empty?
  end


  def == other # :nodoc:
    self.class  == other.class      &&
    @key        == other.key        &&
    @value      == other.value      &&
    @regex_opts == other.regex_opts
  end


  ##
  # Universal iterator for Hash and Array like objects.
  # The data argument must either respond to both :each_with_index
  # and :length, or respond to :each yielding a key/value pair.

  def each_data_item data, &block
    if data.respond_to?(:has_key?) && data.respond_to?(:each)
      data.each(&block)

    elsif data.respond_to?(:each_with_index) && data.respond_to?(:length)
      # We need to iterate through the array this way
      # in case items in it get deleted.
      (data.length - 1).downto(0) do |i|
        block.call i, data[i]
      end
    end
  end


  ##
  # Finds data with the given key and value matcher, optionally recursively.
  # Yields data, key and path Array when block is given.
  # Returns an Array of path arrays.

  def find_in data, path=nil, &block
    return [] unless Array === data || Hash === data

    paths  = []
    path ||= Kronk::Path::PathMatch.new
    path   = Kronk::Path::PathMatch.new path if path.class == Array

    each_data_item data do |key, value|
      c_path = path.dup << key

      found, kmatch = match_node(@key, key)     if @key
      found, vmatch = match_node(@value, value) if @value && (!@key || found)

      if found
        c_path.matches.concat kmatch.to_a
        c_path.matches.concat vmatch.to_a

        yield data, key, c_path if block_given?
        paths << c_path
      end

      paths.concat \
        find_in(data[key], c_path, &block) if @recursive
    end

    paths
  end


  ##
  # Check if data key or value is a match for nested data searches.
  # Returns an array with a boolean expressing if the value matched the node,
  # and the matches found.

  def match_node node, value
    return if ANY_VALUE != node &&
              (Array === value || Hash === value)

    if node.class == value.class
      node == value

    elsif Regexp === node
      match = node.match value.to_s
      return false unless match
      match = match.size > 1 ? match[1..-1] : match.to_a
      [true, match]

    elsif Range === node
      stat  = node.include? value.to_i
      match = [value.to_i] if stat
      [stat, match]

    elsif ANY_VALUE == node
      [true, [value]]

    else
      value.to_s == node.to_s
    end
  end


  ##
  # Decide whether to make path item matcher a regex, range, array, or string.

  def parse_node str
    case str
    when nil, ANYVAL_MATCHER
      ANY_VALUE

    when RANGE_MATCHER
      Range.new $1.to_i, $3.to_i, ($2 == "...")

    when ILEN_MATCHER
      Range.new $1.to_i, ($1.to_i + $2.to_i), true

    when String
      if @regex_opts || str =~ PATH_CHAR_MATCHER

        # Remove extra suffix characters
        str.gsub! %r{(^|[^#{Kronk::Path::RECH}])(\*+\?+|\?+\*+)}, '\1*'
        str.gsub! %r{(^|[^#{Kronk::Path::RECH}])\*+}, '\1*'

        str = Regexp.escape str

        # Remove escaping from special path characters
        str.gsub! %r{#{Kronk::Path::RECH}([#{PATH_CHARS}])}, '\1'
        str.gsub! %r{#{Kronk::Path::RECH}([#{RESC_CHARS}])}, '\1'
        str.gsub! %r{(^|[^#{Kronk::Path::RECH}])([#{SUFF_CHARS}])}, '\1(.\2)'

        Regexp.new "\\A#{str}\\Z", @regex_opts

      else
        str.gsub %r{#{Kronk::Path::RECH}([^#{Kronk::Path::RECH}]|$)}, '\1'
      end

    else
      str
    end
  end


  ##
  # Should this matcher try and find a match recursively.

  def recursive?
    @recursive
  end
end
