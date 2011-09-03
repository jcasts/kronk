##
# Represents a single match of a relative path against a data set.

class Kronk::Path::PathMatch < Array

  attr_accessor :matches

  def initialize *args
    @matches = []
    super
  end


  def dup # :nodoc:
    path_match = super
    path_match.matches = @matches.dup
    path_match
  end


  def append_match_for str, path # :nodoc:
    match = @matches[str.to_i-1]
    if match && !(String === match) && path[-1].empty?
      path[-1] = match
    else
      path[-1] << match.to_s
    end
  end


  ##
  # Builds a path array by replacing %n values with matches.

  def make_path path_map, regex_opts=nil, &block
    path     = []
    escape   = false
    replace  = false
    new_item = true
    rindex   = ""

    path_map.to_s.chars do |chr|
      case chr
      when Kronk::Path::ECH
        escape = true

      when Kronk::Path::DCH
        new_item = true

      when Kronk::Path::RCH
        replace = true
      end and next unless escape

      if replace
        if new_item && !rindex.empty? || chr.to_i.to_s != chr || escape
          append_match_for(rindex, path) unless rindex.empty?
          rindex  = ""
          replace = false
        else
          rindex << chr
        end
      end

      path      << ""  if new_item
      path.last << chr unless replace

      new_item = false
      escape   = false
    end

    append_match_for(rindex, path) unless rindex.empty?

    path
  end
end
