require "rubygems"
require "bundler"
Bundler.setup

require 'rake'
require 'rdoc/task'
require 'rspec/core/rake_task'

# Cane requires ripper, which appears to only work on MRI 1.9
if RUBY_VERSION >= "1.9" && RUBY_ENGINE == "ruby"

  desc "Default Task"
  task :default => [ :quality, :spec ]

  require 'cane/rake_task'
  require 'morecane'

  desc "Run cane to check quality metrics"
  Cane::RakeTask.new(:quality) do |cane|
    cane.abc_max = 20
    cane.style_measure = 100

    cane.use Morecane::EncodingCheck, :encoding_glob => "{app,lib,spec}/**/*.rb"
  end

else
  desc "Default Task"
  task :default => [ :spec ]
end

# run all rspecs
desc "Run all rspec files"
RSpec::Core::RakeTask.new("spec") do |t|
  t.rspec_opts  = ["--color", "--format progress"]
end

# Genereate the RDoc documentation
desc "Create documentation"
RDoc::Task.new do |rdoc|
  rdoc.title = "ftpd"
  rdoc.rdoc_dir = (ENV['CC_BUILD_ARTIFACTS'] || 'doc') + '/rdoc'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('TODO')
  rdoc.rdoc_files.include('CHANGELOG')
  rdoc.rdoc_files.include('MIT-LICENSE')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.options << "--inline-source"
end
