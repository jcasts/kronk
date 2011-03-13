# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugin :isolate

Hoe.spec 'kronk' do
  developer('Jeremie Castagna', 'yaksnrainbows@gmail.com')
  self.readme_file      = "README.rdoc"
  self.history_file     = "History.rdoc"
  self.extra_rdoc_files = FileList['*.rdoc']

  self.extra_deps << ['plist',         '~>3.1.0']
  self.extra_deps << ['json',          '~>1.2']
  self.extra_deps << ['nokogiri',      '~>1.3']
  self.extra_deps << ['i18n',          '~>0.5']
  self.extra_deps << ['activesupport', '>=2.0.0']
  self.extra_deps << ['cookiejar',     '~>0.3.0']
  self.extra_deps << ['rack',          '~>1.0']

  self.extra_dev_deps << ['mocha', '~>0.9.10']
end

def benchmark num=1000
  start = Time.now

  num.times do
    yield
  end

  puts "Ran #{num} times: #{(Time.now - start).to_f / num}"
end

$: << "lib"
require 'kronk'
p Kronk::VERSION

namespace :bm do

  desc "Run performance benchmarks on diff and parsing"
  task :full do

    benchmark(100) do
      Kronk.compare "prod.txt", "beta.txt"
    end
  end


  desc "Run performance benchmarks on diffs"
  task :diff do
    left = Kronk::Request.retrieve("prod.txt").parsed_body
    right = Kronk::Request.retrieve("beta.txt").parsed_body

    diff = Kronk::Diff.new_from_data left, right

    benchmark(100) do
      diff.create_diff
    end
  end
end

# vim: syntax=ruby
