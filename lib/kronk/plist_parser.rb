class Kronk

  ##
  # Simple plist wrapper to add :parse method.

  class PlistParser

    ##
    # Alias for Plist.parse_xml

    def self.parse plist
      require 'plist'
      Plist.parse_xml plist
    end
  end
end
