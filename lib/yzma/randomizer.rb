class Yzma

  ##
  # Randomizes params, data, and headers for Yzma requests.

  class Randomizer

    def initialize
      @options = {}
    end


    def to_options
      @options.dup
    end


    def randomize_param name, values, options={}
      @options[:query] ||= {}
      assign_random @options[:query], name, values, options
    end


    def randomize_data name, values, options={}
      @options[:data] ||= {}
      assign_random @options[:data], name, values, options
    end


    def randomize_header name, values, options={}
      @options[:headers] ||= {}
      assign_random @options[:headers], name, values, options
    end


    def assign_random obj, key, values, options={}
      random_value = pick_random values, options
      obj[key] = random_value if random_value
    end


    def pick_random val, options={}
      val = File.readlines val if String === val
      val = val.to_a           if Range === val

      val << ""  if options[:allow_blank]
      val << nil if options[:optional]

      return if val.empty?

      val[rand(val.length)]
    end
  end
end
