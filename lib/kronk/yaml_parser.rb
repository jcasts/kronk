class Kronk

  ##
  # Simple yaml wrapper to support Kronk's parser interface.

  class YamlParser

    ##
    # Wrapper for YAML.load

    def self.parse yaml
      YAML.load(yaml) || raise(ParserError, "unparsable YAML")

    rescue ArgumentError
      raise ParserError, "unparsable YAML"
    end
  end
end

