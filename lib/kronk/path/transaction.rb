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
#   # Select all element names, delete the one at index 2,
#   # and move the element with the value "Tory" to the same path but
#   # with the key renamed to "boo"
#   Transaction.run data do |t|
#     t.select "*/name"
#     t.move "**=Tory" => "%%/boo"
#     t.delete "2"
#   end
#
#   # => [
#   #  {:name => "Jamie"},
#   #  {:name => "Adam"},
#   #  {:name => "Grant"},
#   #  {"boo" => "Tory"},
#   # ]

class Kronk::Path::Transaction

  ##
  # Create new Transaction instance and run it with a block.
  # Equivalent to:
  #   Transaction.new(data).run(opts)

  def self.run data, opts={}, &block
    new(data).run opts, &block
  end


  attr_accessor :actions

  ##
  # Create a new Transaction instance with a the data object to perform
  # operations on.

  def initialize data
    @data     = data
    @new_data = nil
    @actions  = []

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
    new_data  = @data
    prev_type = nil
    prev_data = nil

    @actions.each do |type, paths|
      new_data = send("transaction_#{type}", new_data, *paths)
    end

    remake_arrays new_data, opts[:keep_indicies]
  end


  def remake_arrays new_data, except_modified=false # :nodoc:
    remake_paths = @make_array.keys.sort{|p1, p2| p2.length <=> p1.length}

    remake_paths.each do |path_arr|
      key  = path_arr.last
      obj = Kronk::Path.data_at_path path_arr[0..-2], new_data

      next unless obj && Hash === obj[key]

      if except_modified
        data_at_path = Kronk::Path.data_at_path(path_arr, @data)
        next if !data_at_path || obj[key].length != data_at_path.length
      end

      obj[key] = hash_to_ary obj[key]
    end

    new_data = hash_to_ary new_data if
      Array === @data && Hash === new_data &&
      (!except_modified || @data.length == new_data.length)

    new_data
  end


  def remap_make_arrays new_path, old_path # :nodoc:
    @make_array[new_path] = true and return if @make_array[old_path]

    @make_array.keys.each do |path|
      if path[0...old_path.length] == old_path
        path[0...old_path.length] = new_path
      end
    end
  end


  def transaction_select data, *data_paths # :nodoc:
    return data if data_paths.empty?

    transaction data, data_paths, true do |sdata, cdata, key, path, tpath|
      sdata[key] = cdata[key]
    end
  end


  def transaction_delete data, *data_paths # :nodoc:
    transaction data, data_paths do |new_curr_data, curr_data, key|
      new_curr_data.delete key
    end
  end


  def transaction_move data, *path_pairs # :nodoc:
    return data if path_pairs.empty?
    path_val_hash = {}

    new_data =
      transaction data, path_pairs do |sdata, cdata, key, path, tpath|
        path_val_hash[tpath] = sdata.delete key
        remap_make_arrays(tpath, path)
      end

    force_assign_paths new_data, path_val_hash
  end


  def transaction_map data, *path_pairs # :nodoc:
    return data if path_pairs.empty?
    path_val_hash = {}

    transaction data, path_pairs do |sdata, cdata, key, path, tpath|
      tpath ||= path
      path_val_hash[tpath] = sdata.delete key
      remap_make_arrays(tpath, path)
    end

    force_assign_paths data.class.new, path_val_hash
  end


  def transaction data, data_paths, create_empty=false # :nodoc:
    data_paths = data_paths.compact
    return @new_data || data if data_paths.empty?

    @new_data = create_empty ? Hash.new : data.dup

    if Array === @new_data
      @new_data = ary_to_hash @new_data
    end

    data_paths.each do |data_path|
      # If data_path is an array, the second element is the path where the value
      # should be mapped to.
      data_path, target_path = data_path

      Kronk::Path.find data_path, data do |obj, k, path|
        curr_data     = data
        new_curr_data = @new_data

        path.each_with_index do |key, i|
          break unless new_curr_data

          if i == path.length - 1
            tpath = path.make_path target_path if target_path
            yield new_curr_data, curr_data, key, path, tpath if block_given?

          else
            if create_empty
              new_curr_data[key] ||= Hash.new

            elsif new_curr_data[key] == curr_data[key]
              new_curr_data[key] = Array === new_curr_data[key] ?
                                    ary_to_hash(curr_data[key]) :
                                    curr_data[key].dup
            end

            @make_array[path[0..i]] = true if Array === curr_data[key]

            new_curr_data = new_curr_data[key]
            curr_data     = curr_data[key]
          end
        end
      end
    end

    @new_data
  end


  def force_assign_paths data, path_val_hash # :nodoc:
    return data if path_val_hash.empty?
    @new_data = (data.dup rescue [])

    path_val_hash.each do |path, value|
      curr_data     = data
      new_curr_data = @new_data
      prev_data     = nil
      prev_key      = nil
      prev_path     = []

      path.each_with_index do |key, i|
        if Array === new_curr_data
          new_curr_data          = ary_to_hash new_curr_data
          prev_data[prev_key]    = new_curr_data if prev_data
          @new_data              = new_curr_data if i == 0
          @make_array[prev_path] = true          if i == 0
        end

        last      = i == path.length - 1
        prev_path = path[0..(i-1)] if i > 0
        curr_path = path[0..i]
        next_key  = path[i+1]

        # new_curr_data is a hash from here on

        @make_array.delete prev_path unless is_integer?(key)

        new_curr_data[key] = value and break if last

        if ary_or_hash?(curr_data) && ary_or_hash?(curr_data[key])
          new_curr_data[key] ||= curr_data[key]

        elsif !ary_or_hash?(new_curr_data[key])
          new_curr_data[key] = is_integer?(next_key) ? [] : {}
        end

        @make_array[curr_path] = true if Array === new_curr_data[key]

        prev_key      = key
        prev_data     = new_curr_data
        new_curr_data = new_curr_data[key]
        curr_data     = ary_or_hash?(curr_data) ? curr_data[key] : nil
      end
    end

    @new_data
  end


  def is_integer? item # :nodoc:
    item.to_s.to_i.to_s == item.to_s
  end


  def ary_or_hash? obj # :nodoc:
    Array === obj || Hash === obj
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
    @new_data = nil
    @actions.clear
    @make_array.clear
  end


  ##
  # Queues path selects for transaction.

  def select *paths
    if @actions.last && @actions.last[0] == :select
      @actions.last[1].concat paths
    else
      @actions << [:select, paths]
    end
  end


  ##
  # Queues path deletes for transaction.

  def delete *paths
    @actions << [:delete, paths]
  end


  ##
  # Queues path moving for transaction. Moving a path will attempt to
  # keep the original data structure and only affect the given paths.
  # Empty hashes or arrays after a move are deleted.
  #   t.move "my/path/1..4/key" => "new_path/%1/key",
  #          "other/path/*"     => "moved/%1"

  def move path_maps
    @actions << [:move, Array(path_maps)]
  end


  ##
  # Queues path mapping for transaction. Mapping a path will only keep the
  # mapped values, completely replacing the original data structure.
  #   t.map "my/path/1..4/key" => "new_path/%1/key",
  #         "other/path/*"     => "moved/%1"

  def map path_maps
    @actions << [:map, Array(path_maps)]
  end
end
