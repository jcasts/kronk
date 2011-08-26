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
        if chr.to_i.to_s != chr
          path.last << @matches[rindex.to_i+1].to_s unless rindex.empty?
          rindex  = ""
          replace = false
        else
          rindex << chr
          next
        end
      end

      path      << "" if new_item
      path.last << chr

      new_item = false
      escape   = false
    end

    path.last << @matches[rindex.to_i+1].to_s unless rindex.empty?

    path
  end
end
