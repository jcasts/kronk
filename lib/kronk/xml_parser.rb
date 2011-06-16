class Kronk

  ##
  # Rails-like XML parser.

  class XMLParser

    ##
    # Load required gems. Loads Nokogiri. ActiveSupport will attempt to be
    # loaded if String#pluralize is not defined.

    def self.require_gems
      require 'nokogiri'

      return if "".respond_to?(:pluralize)

      # Support for new and old versions of ActiveSupport
      active_support_versions = %w{active_support/inflector activesupport}
      asupp_i = 0

      begin
        require active_support_versions[asupp_i]

      rescue LoadError => e
        raise unless e.message =~ /-- active_?support/
        asupp_i = asupp_i.next
        retry if asupp_i < active_support_versions.length
      end
    end


    ##
    # Takes an xml string and returns a data hash.
    # Ignores blank spaces between tags.

    def self.parse str
      require_gems

      root_node = Nokogiri.XML str do |config|
        config.default_xml.noblanks
      end

      hash = node_value root_node.children
      hash.values.first
    end


    ##
    # Build a hash from a nokogiri xml node.

    def self.node_value xml_node, as_array=false
      case xml_node
      when Nokogiri::XML::Text    then xml_node.text

      # Returns hash or array
      when Nokogiri::XML::NodeSet then node_set_value(xml_node, as_array)

      # Returns node name and value
      when Nokogiri::XML::Element then element_node_value(xml_node)
      end
    end


    ##
    # Returns the value for an xml node set.
    # Can be a Hash, Array, or String

    def self.node_set_value xml_node, as_array=false
      orig = {}
      data = as_array ? Array.new : Hash.new

      xml_node.each do |node|
        node_data, name = node_value node
        return node_data unless name

        case data
        when Array
          data << node_data
        when Hash
          orig[name] ||= node_data

          if data.has_key?(name)
            data[name] = [data[name]] if data[name] == orig[name]
            data[name] << node_data
          else
            data[name] = node_data
          end
        end
      end

      data
    end


    ##
    # Returns an Array containing the value of an element node
    # and its name.

    def self.element_node_value xml_node
      name     = xml_node.name
      datatype = xml_node.attr :type
      is_array = array? xml_node.children, name
      data     = node_value xml_node.children, is_array

      data = case datatype
             when 'array'   then data.to_a
             when 'symbol'  then data.to_sym
             when 'integer' then data.to_i
             when 'float'   then data.to_f
             when 'boolean'
               data == 'true' ? true : false
             else
               data
             end

      [data, name]
    end


    ##
    # Checks if a given node set should be interpreted as an Array.

    def self.array? node_set, parent_name=nil
      names = node_set.map do |n|
        return unless Nokogiri::XML::Element === n
        n.name
      end

      return false unless names.uniq.length == 1
      return true  if     names.length > 1
      return false unless parent_name

      names.first == parent_name             ||
      names.first.respond_to?(:pluralize) &&
        names.first.pluralize == parent_name ||
      "#{names.first}s" == parent_name
    end
  end
end
