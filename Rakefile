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


namespace :bm do

  desc "Run performance benchmarks on diff"
  task :diff do
    $: << "lib"
    require 'kronk'

    start = Time.now
    number = 1000

    number.times do
      Kronk.compare "prod.txt", "beta.txt"
    end

    puts "Ran #{number} times: #{(Time.now - start).to_f / number}"
  end
end

# vim: syntax=ruby
