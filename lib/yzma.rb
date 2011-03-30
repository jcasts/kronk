##
# Yzma bosses Kronk around to give you meaningful diff variation
# statistical data.

class Yzma

  require 'kronk'
  require 'yzma/report'
  require 'yzma/randomizer'

  ##
  # Construct and run an Yzma report.

  def self.report name=nil, &block
    yzma = new name

    yzma.instance_eval(&block)

    yzma.report.header << "Ran #{yzma.comparisons} URI comparison(s)\n"
    yzma.report.header << "Iterated a total of #{yzma.iterations} case(s)\n"

    curr_req = nil

    yzma.report.write do |req, data|
      next unless data[:diff].count > 0
      "\n#{data[:diff].count} diffs:\n#{req[0]} - #{req[1]}\n#{req[2].inspect}\n"
    end
  end


  attr_reader :report, :comparisons, :iterations

  ##
  # Initialize Izma with optional name.

  def initialize name=nil
    @name   = name || 'Yzma Report'
    @report = Report.new @name
    @comparisons = 0
    @iterations  = 0
  end


  ##
  # Compare two paths or uris. Second uri may be omitted.
  # Supports all Kronk.compare options, plus:
  # :count:: Integer - number of times to run the endpoint; default 1.

  def compare uri1, uri2, options={}, &block
    count = options.delete(:count) || 1

    @comparisons = @comparisons.next

    1.upto(count) do |i|
      randomizer = Randomizer.new
      randomizer.instance_eval &block if block_given?

      randomized_opts = options.merge randomizer.to_options
      diff = Kronk.compare uri1, uri2, randomized_opts

      $stdout << (diff.count > 0 ? "D" : ".")
      $stdout.flush

      @iterations = @iterations.next

      @report.add [uri1, uri2, randomized_opts], :diff => diff
    end

    $stdout << "\n\n"
  end
end




# host args optional, may be set in the block for each item tested
# if no host is set, :name option must be used
Yzma.report :my_report do

  # supports Kronk#compare options
  compare "syndication.yellowpages.com/_priv/sysinfo",
          "beta-syndication.yellowpages.com/_priv/sysinfo", :count => 10 do
    randomize_param :param1, 1..23, :allow_blank => true, :optional => true
    randomize_param :param2, ["val1", "val2"]
  end
end


##
# Report format:
#
# = Report for host1[, host2] | name
# requests count
# total diffs
# diff avg
# avg request time for left and right side
# data filters
# 10 most significant http request diffs w/ kronk command to run to get diff
#
# == Path: path1[, path2]
# requests count
# total diffs
# diff avg
# avg request time for left and right side
# data filters
# 10 most significant http request diffs w/ kronk command to run to get diff
