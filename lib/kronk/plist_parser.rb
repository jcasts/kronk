class Kronk

  ##
  # Simple plist wrapper to support Kronk's parser interface.

  class PlistParser

    ##
    # Wrapper for Plist.parse_xml

    def self.parse plist
      require 'plist'
      Plist.parse_xml(plist) || raise(ParserError, "invalid Plist")

    rescue RuntimeError
      raise ParserError, "unparsable Plist"

    rescue LoadError => e
      raise unless e.message =~ /-- plist/
      raise MissingDependency, "Please install the plist gem and try again"
    end
  end
end
