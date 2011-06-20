class Kronk

  # TODO:
  #  * apply ignore and only in the order given in the cmd line?
  #  * cleanup the affect_parent implementation

  ##
  # Wraps a complex data structure to provide a search-driven interface.

  class DataSet

    # Deep merge proc for recursive Hash merging.
    DEEP_MERGE =
      proc do |key,v1,v2|
        Hash === v1 && Hash === v2 ? v1.merge(v2,&DEEP_MERGE) : v2
      end


    attr_accessor :data

    def initialize data
      @data = data
    end


    ##
    # Modify the data object by passing inclusive or exclusive data paths.
    # Supports the following options:
    # :only_data:: String/Array - keep data that matches the paths
    # :only_data_with:: String/Array - keep data with a matched child
    # :ignore_data:: String/Array - remove data that matches the paths
    # :ignore_data_with:: String/Array - remove data with a matched child
    #
    # Note: the data is processed in the following order:
    # * only_data_with
    # * ignore_data_with
    # * only_data
    # * ignore_data

    def modify options
      collect_data_points options[:only_data_with], true if
        options[:only_data_with]

      delete_data_points options[:ignore_data_with], true if
        options[:ignore_data_with]

      collect_data_points options[:only_data]  if options[:only_data]

      delete_data_points options[:ignore_data] if options[:ignore_data]

      @data
    end


    ##
    # Keep only specific data points from the data structure.

    def collect_data_points data_paths, affect_parent=false
      new_data = @data.class.new

      [*data_paths].each do |data_path|
        opts = Path.parse_regex_opts! data_path
        data_path << "/.." if affect_parent

        Path.find data_path, @data, opts do |data, k, path|
          curr_data     = @data
          new_curr_data = new_data

          path.each_with_index do |key, i|
            if i == path.length - 1
              new_curr_data[key]   = curr_data[key]
            else
              new_curr_data[key] ||= curr_data[key].class.new
              new_curr_data        = new_curr_data[key]
              curr_data            = curr_data[key]
            end
          end
        end
      end

      @data.replace new_data
    end


    ##
    # Remove specific data points from the data structure.

    def delete_data_points data_paths, affect_parent=false
      [*data_paths].each do |data_path|
        opts = Path.parse_regex_opts! data_path
        data_path << "/.." if affect_parent

        Path.find data_path, @data, opts do |obj, k, path|
          next unless obj.respond_to? :[]

          del_method = Array === obj ? :delete_at : :delete
          obj.send del_method, k
        end
      end

      @data
    end
  end
end
