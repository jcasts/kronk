##
# Yzma bosses Kronk around to give you meaningful diff variation
# statistical data.
#
# TODO: report on what uri requests were different.

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
      next unless data[:diff] > 0
      "\n#{data[:diff]} avg diffs:\n#{req[0]} - #{req[1]}\n"
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
  # :title:: String - title to display when running compares.

  def compare uri1, uri2, options={}, &block
    options = options.dup
    count   = options.delete(:count) || 1
    title   = options.delete(:title)  || "#{uri1} --- #{uri2}"

    @comparisons = @comparisons.next

    diff_avg = 0
    diff_cnt = 0

    puts name
    1.upto(count) do |i|
      randomizer = Randomizer.new
      randomizer.instance_eval &block if block_given?

      randomized_opts = options.merge randomizer.to_options

      begin
        diff = Kronk.compare uri1, uri2, randomized_opts

        diff_avg = (diff_avg * diff_cnt + diff.count) / (diff_cnt + 1)
        diff_cnt = diff_cnt.next

        @iterations = @iterations.next

        $stdout << (diff.count > 0 ? "D" : ".")

      rescue Kronk::Request::NotFoundError
        $stdout << "E"
      end

      $stdout.flush
    end

    @report.add [uri1, uri2], :diff => diff_avg

    $stdout << "\n\n"
  end
end
