Gem::Specification.new do |spec|
  spec.name = "raval"
  spec.version = "0.0.1"
  spec.summary = "A threaded FTP daemon (ftpd) framework"
  spec.description = "Build a custom FTP daemon backed by a datastore of your choice"
  spec.files =  Dir.glob("{examples,lib,spec}/**/**/*") + ["Gemfile", "README.markdown","MIT-LICENSE"]
  spec.has_rdoc = true
  spec.extra_rdoc_files = %w{README.markdown MIT-LICENSE }
  spec.rdoc_options << '--title' << 'raval FTPd Documentation' <<
                       '--main'  << 'README.markdown' << '-q'
  spec.authors = ["James Healy"]
  spec.email   = ["jamed@yob.id.au"]
  spec.homepage = "http://github.com/yob/raval"
  spec.required_ruby_version = ">=1.9.2"

  spec.add_development_dependency("rake")
  spec.add_development_dependency("rdoc")
  spec.add_development_dependency("rspec", "~>2.6")
  spec.add_development_dependency("cane", "~>2.2.3")
  spec.add_development_dependency("morecane")

  spec.add_dependency('celluloid-io')
end
