##
# Path Transactions are a convenient way to apply selections and deletions
# to complex data structures without having to know what state the data will
# be in after each operation.
#
#   data = [
#     {:name => "Jamie", :id => "12345"},
#     {:name => "Adam",  :id => "54321"},
#     {:name => "Kari",  :id => "12345"},
#     {:name => "Grant", :id => "12345"},
#     {:name => "Tory",  :id => "12345"},
#   ]
#
#   # Select all element names but delete the one at index 2
#   Transaction.run data do |t|
#     t.select "*/name"
#     t.delete "2"
#   end
#
#   # => [
#   #  {:name => "Jamie"},
#   #  {:name => "Adam"},
#   #  {:name => "Grant"},
#   #  {:name => "Tory"},
#   # ]

class Kronk::Path::Transaction

  ##
  # Create new Transaction instance and run it with a block.
  # Equivalent to:
  #   Transaction.new(data).run(opts)

  def self.run data, opts={}, &block
    new(data).run opts, &block
  end


  ##
  # Create a new Transaction instance with a the data object to perform
  # operations on.

  def initialize data
    @data    = data
    @actions = Hash.new{|h,k| h[k] = []}

    @make_array = {}
  end


  ##
  # Run operations as a transaction.
  # See Transaction#results for supported options.

  def run opts={}, &block
    clear
    yield self if block_given?
    results opts
  end


  ##
  # Returns the results of the transaction operations.
  # To keep the original indicies of modified arrays, and return them as hashes,
  # pass the :keep_indicies => true option.

  def results opts={}
    new_data = transaction_select @data, *@actions[:select]
    new_data = transaction_delete new_data, *@actions[:delete]
    new_data = remake_arrays new_data, opts[:keep_indicies]
    new_data
  end


  def remake_arrays new_data, except_modified=false # :nodoc:
    @make_array.each do |path_arr, v|
      key  = path_arr.last
      obj = Kronk::Path.data_at_path path_arr[0..-2], new_data

      next unless Hash === obj[key]
      next if except_modified &&
        obj[key].length !=
          Kronk::Path.data_at_path(path_arr, @data).length

      obj[key] = hash_to_ary obj[key]
    end

    new_data = hash_to_ary new_data if
      Array === @data && Hash === new_data &&
      (!except_modified || @data.length == new_data.length)

    new_data
  end


  def transaction_select data, *data_paths # :nodoc:
    data_paths = data_paths.compact
    return data if data_paths.empty?

    new_data = Hash.new

    data_paths.each do |data_path|
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
              @make_array[path[0..i]] = true
            end

            new_curr_data = new_curr_data[key]
            curr_data     = curr_data[key]
          end
        end
      end
    end

    new_data
  end


  def transaction_delete data, *data_paths # :nodoc:
    data_paths = data_paths.compact
    return data if data_paths.empty?

    new_data = data.dup

    if Array === new_data
      new_data = ary_to_hash new_data
    end

    data_paths.each do |data_path|
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
              @make_array[path[0..i]] = true
            end

            new_curr_data = new_curr_data[key]
            curr_data     = curr_data[key]
          end
        end
      end
    end

    new_data
  end


  def force_assign_paths data, path_val_hash # :nodoc:
    new_data = data.dup

    path_val_hash.each do |path, value|
      curr_data     = data
      new_curr_data = new_data
      prev_data     = nil
      prev_key      = nil

      path.each_with_index do |key, i|
        last      = i == path.length - 1
        curr_path = []
        curr_path = path[0..(i-1)] if i > 0
        next_path = path[0..i]

        new_curr_data[key] = value and break if last

        new_curr_data[key] = curr_data[key].dup rescue nil

        if Array === new_curr_data
          new_curr_data          = ary_to_hash new_curr_data
          prev_data[prev_key]    = new_curr_data if prev_data
          @make_array[curr_path] = true
        end

        # curr_data is a hash from here on
        @make_array.delete curr_path unless Integer === key

        unless Array === new_curr_data[key] || Hash === new_curr_data[key]
          new_curr_data[key]     = Hash.new
          @make_array[next_path] = true if Integer === key
        end

        prev_key      = key
        prev_data     = new_curr_data
        new_curr_data = new_curr_data[key]
        curr_data     = curr_data[key]
      end
    end

    new_data
  end


  def ary_to_hash ary # :nodoc:
    hash = {}
    ary.each_with_index{|val, i| hash[i] = val}
    hash
  end


  def hash_to_ary hash # :nodoc:
    hash.keys.sort.map{|k| hash[k] }
  end


  ##
  # Clears the queued actions and cache.

  def clear
    @actions.clear
    @make_array.clear
  end


  ##
  # Queues path selects for transaction.

  def select *paths
    @actions[:select].concat paths
  end


  ##
  # Queues path deletes for transaction.

  def delete *paths
    @actions[:delete].concat paths
  end


  ##
  # Queues path moving for transaction. Moving a path will attempt to
  # keep the original data structure and only affect the given paths.
  # Empty hashes or arrays after a move are deleted.
  #   t.move "my/path/1..4/key" => "new_path/%d/key",
  #          "other/path/*"     => "moved/%d"

  def move path_maps
  end


  ##
  # Queues path mapping for transaction. Mapping a path will only keep the
  # mapped values, completely replacing the original data structure.

  def map path_maps
  end
end
