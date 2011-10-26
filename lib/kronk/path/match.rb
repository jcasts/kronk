##
# Represents the single match of a relative path against a data set.

class Kronk::Path::Match < Array

  attr_accessor :matches, :splat

  def initialize *args
    @matches = []
    @splat   = []
    super
  end


  def [] selector
    path_match = super

    if self.class === path_match
      path_match.matches = @matches.dup
      path_match.splat   = @splat.map{|key, sp| [key, sp.dup]}
    end

    path_match
  end


  def append_splat id, key # :nodoc:
    if @splat[-1] && @splat[-1][0] == id
      @splat[-1][1] << key
    else
      @splat << [id, [key]]
    end
  end


  def dup # :nodoc:
    path_match = super
    path_match.matches = @matches.dup
    path_match.splat   = @splat.map{|key, sp| [key, sp.dup]}
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
  # Builds a path array by replacing %n and %% values with matches and splat.
  #
  #   matches = Path.find_in "**/foo=bar", data
  #   # [["path", "to", "foo"]]
  #
  #   matches.first.make_path "root/%%/foo"
  #   # ["root", "path", "to", "foo"]
  #
  #   matches = Path.find_in "path/*/(foo)=bar", data
  #   # [["path", "to", "foo"]]
  #
  #   matches.first.make_path "root/%1/%2"
  #   # ["root", "to", "foo"]

  def make_path path_map, regex_opts=nil, &block
    tmpsplat = @splat.dup
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
        if replace
          if rindex.empty?
            unless tmpsplat.empty?
              items = tmpsplat.shift[1].dup
              if new_item
                new_item = false
              else
                path[-1] = path[-1].dup << items.shift
              end
              path.concat items
            end
            replace = false
          else
            append_match_for(rindex, path)
            rindex = ""
          end

          next
        else
          replace = true
        end
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
