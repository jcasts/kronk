# -*- ruby -*-

require 'rubygems'
require 'hoe'


if ENV['version']
  gem 'kronk', ENV['version']
else
  $: << "lib"
  Hoe.plugin :isolate
end


require 'kronk'
puts "kronk-#{Kronk::VERSION}"


Hoe.spec 'kronk' do
  developer('Jeremie Castagna', 'yaksnrainbows@gmail.com')
  self.readme_file      = "README.rdoc"
  self.history_file     = "History.rdoc"
  self.extra_rdoc_files = FileList['*.rdoc']

  self.extra_deps << ['json',       '~>1.5']
  self.extra_deps << ['cookiejar',  '~>0.3.0']
  self.extra_deps << ['ruby-path',  '~>1.0.0']
  self.extra_deps << ['mime-types', '~>1.18.0']

  self.extra_dev_deps << ['plist',    '~>3.1.0']
  self.extra_dev_deps << ['nokogiri', '~>1.4']
  self.extra_dev_deps << ['mocha',    '~>0.9.12']
end


class Object

  BENCHMARKS = {}

  def bm name=nil
    start = Time.now
    yield
    span = Time.now - start

    if BENCHMARKS[name]
      t = BENCHMARKS[name][:time]
      w = BENCHMARKS[name][:weight]

      t = t + span
      w += 1

      BENCHMARKS[name] = {:time => t, :weight => w}
    else
      BENCHMARKS[name] = {:time => span, :weight => 1}
    end
  end
end


def benchmark num=1000
  start = Time.now

  num.times do
    yield
  end

  puts "Ran #{num} times: #{(Time.now - start).to_f / num}"
end


namespace :bm do

  desc "Run performance benchmarks on diff and parsing"
  task :full do

    benchmark(100) do
      Kronk.compare("prod.txt", "beta.txt").count
    end
  end


  desc "Run performance benchmarks on diffs"
  task :diff do
    left = Kronk.retrieve("prod.txt").body
    right = Kronk.retrieve("beta.txt").body

    diff = Kronk::Diff.new left, right

    arr1 = diff.str1.split "\n"
    arr2 = diff.str2.split "\n"

    benchmark(100) do
      #arr1.each{|i| 0.upto(5){|j| foo = j+123}}
      #arr2.each{|i| foo = 'foobar'}
      #arr2.each{|i| i == 'foobar'}
      diff.create_diff
      #diff.common_sequences arr1, arr2
      #diff.find_common arr1, arr2
      #`diff prod.txt beta.txt`
    end

    Object::BENCHMARKS.each do |name, bm|
      puts "#{name} (#{bm[:weight]/100}): #{bm[:time] / 100}"
    end rescue nil
  end
end

# vim: syntax=ruby
