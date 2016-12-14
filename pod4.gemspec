lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pod4/version'

Gem::Specification.new do |spec|
  spec.name          = "pod4"
  spec.version       = Pod4::VERSION
  spec.authors       = ["Andy Jones"]
  spec.email         = ["andy.jones@twosticksconsulting.co.uk"]
  spec.summary       = %q|Totally not an ORM|
  spec.description   = <<-DESC.gsub(/^\s+/, "")
    Provides a simple, common framework to talk to a bunch of data sources,
    using model classes which consist of a bare minimum of DSL plus vanilla Ruby
    inheritance.
  DESC

  spec.homepage      = "https://bitbucket.org/andy-twosticks/pod4"
  spec.license       = "MIT"

  spec.files         = `hg status -macn0`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.extra_rdoc_files = spec.files.grep(%r{^md/})

  spec.add_runtime_dependency "devnull",    '~>0.1'
  spec.add_runtime_dependency "octothorpe", '~>0.3'

end
