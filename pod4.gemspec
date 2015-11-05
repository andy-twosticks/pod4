lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pod4/version'

Gem::Specification.new do |spec|
  spec.name          = "pod4"
  spec.version       = Pod4::VERSION
  spec.authors       = ["Andy Jones"]
  spec.email         = ["andy.jones@jameshall.co.uk"]
  spec.summary       = %q|Totally not an ORM|
  #spec.description   = %q{TODO: Write a longer description.}
  #spec.homepage      = ""
  spec.license       = "Closed"

  spec.files         = `hg status -macn0`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.extra_rdoc_files = spec.files.grep(%r{^md/})

  #spec.requirements << 'STOMP Messaging server'

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake",    "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rdoc"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-doc"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "ripper-tags"
  spec.add_development_dependency "geminabox"

  spec.add_runtime_dependency "octothorpe"
end
