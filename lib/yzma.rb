require 'rubygems'
require 'kronk'

##
# Yzma bosses Kronk around to give you meaningful diff variation
# statistical data.

class Yzma

  require 'yzma/report'
  require 'yzma/randomizer'


  ##
  # Parses ARGV for Yzma.

  def self.parse_args argv
    options = {:files => []}

    opts = OptionParser.new do |opt|
      opt.program_name = File.basename $0
      opt.version = Kronk::VERSION
      opt.release = nil

      opt.banner = <<-STR

#{opt.program_name} #{opt.version}

Run diff reports between two URI requests.

  Usage:
    #{opt.program_name} --help
    #{opt.program_name} --version
    #{opt.program_name} file1 [file2 ...]
      STR
    end

    opts.parse! argv

    options[:files] = argv.dup

    if options[:files].empty?
      $stderr << "\nError: At least one report file must be specified.\n"
      $stderr << "See 'yzma --help' for usage\n\n"
      exit 1
    end

    options
  end


  ##
  # Construct and run an Yzma report.

  def self.report name_or_report=nil, &block
    yzma = new name_or_report

    yzma.instance_eval(&block)

    yzma.report.header << "Ran #{yzma.comparisons} URI comparison(s)"
    yzma.report.header << "Iterated a total of #{yzma.iterations} case(s)"

    curr_req = nil

    yzma.report.write do |req, data|
      next unless data[:diff] > 0
      "\n#{data[:diff]} avg diffs:\n#{req[0]} - #{req[1]}\n"
    end
  end


  ##
  # Run the Yzma command.

  def self.run argv=ARGV
    options = parse_args argv
    options[:files].each do |file|
      self.instance_eval File.read(file)
    end

    exit 2 if self.diffs > 0
  end


  class << self
    attr_accessor :diffs
  end

  self.diffs = 0


  attr_reader :report, :comparisons, :iterations

  ##
  # Initialize Izma with optional name.

  def initialize name_or_report=nil
    case name_or_report
    when String
      @name   = name_or_report
      @report = Report.new @name

    when Report
      @report = name_or_report
      @name   = @report.name

    else
      @name   = 'Yzma Report'
      @report = Report.new @name
    end

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

    puts title
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
        self.class.diffs = self.class.diffs + diff.count

      rescue Kronk::Request::NotFoundError
        $stdout << "E"
      end

      $stdout.flush
    end

    @report.add [uri1, uri2], :diff => diff_avg

    $stdout << "\n\n"
  end
end
