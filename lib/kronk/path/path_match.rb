class Kronk::Path::PathMatch < Array

  attr_reader :matches

  def initialize *args
    @matches = []
    super
  end


  def dup # :nodoc:
    path_match = super
    path_match.matches.concat @matches
    path_match
  end
end
