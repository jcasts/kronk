class Kronk::Path::Transaction

  def self.run data, opts={}, &block
    new(data).run opts, &block
  end


  def initialize data
    @data    = data
    @actions = Hash.new{|h,k| h[k] = []}

    @make_array = []
  end


  def run opts={}, &block
    clear
    yield self
    results opts
  end


  def results opts={}
    new_data = transaction_select @data, *@actions[:select]
    new_data = transaction_delete new_data, *@actions[:delete]
    new_data = remake_arrays new_data, opts[:show_indicies]
    new_data
  end


  def remake_arrays new_data, except_modified=false
    @make_array.each do |(data, path_arr, i)|
      key = path_arr[i]

      next unless Hash === data[key]
      next if except_modified &&
        data[key].length !=
          Kronk::Path.data_at_path(path_arr[0..i], @data).length

      data[key] = hash_to_ary data[key]
    end

    new_data = hash_to_ary new_data if Array === @data && Hash === new_data
    new_data
  end


  def transaction_select data, *data_paths
    return data if data_paths.empty?

    new_data = Hash.new

    [*data_paths].each do |data_path|
      Kronk::Path.find data_path, data do |obj, k, path|

        curr_data     = data
        new_curr_data = new_data

        path.each_with_index do |key, i|
          if i == path.length - 1
            new_curr_data[key] = curr_data[key]

          else
            new_curr_data[key] ||= Hash.new

            # Tag data item for conversion to Array.
            # Hashes are used to conserve position of Array elements.
            if Array === curr_data[key]
              @make_array << [new_curr_data, path, i]
            end

            new_curr_data = new_curr_data[key]
            curr_data     = curr_data[key]
          end
        end
      end
    end

    new_data
  end


  def transaction_delete data, *data_paths
    return data if data_paths.empty?

    new_data = Hash.new

    [*data_paths].each do |data_path|
      Kronk::Path.find data_path, data do |obj, k, path|

        curr_data     = data
        new_curr_data = new_data

        path.each_with_index do |key, i|
          if i == path.length - 1
            new_curr_data.delete key

          else
            new_curr_data[key] = curr_data[key].dup

            if Array === new_curr_data[key]
              new_curr_data[key] = ary_to_hash new_curr_data[key]
              @make_array << [new_curr_data, path, i]
            end

            new_curr_data = new_curr_data[key]
            curr_data     = curr_data[key]
          end
        end
      end
    end

    new_data
  end


  def ary_to_hash ary
    hash = {}
    ary.each_with_index{|val, i| hash[i] = val}
    hash
  end


  def hash_to_ary hash
    hash.keys.sort.map{|k| hash[k] }
  end


  def clear
    @actions.clear
    @make_array.clear
  end


  def select *paths
    @actions[:select].concat paths
  end


  def delete *paths
    @actions[:delete].concat paths
  end
end
