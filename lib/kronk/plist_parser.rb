class Kronk

  ##
  # Simple plist wrapper to add :parse method.

  class PlistParser < Plist

    ##
    # Alias for Plist.parse_xml

    def self.parse plist
      parse_xml plist
    end
  end
end
