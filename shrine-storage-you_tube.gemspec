# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'shrine/storage/you_tube/version'

Gem::Specification.new do |spec|
  spec.name          = "shrine-storage-you_tube"
  spec.version       = Shrine::Storage::YouTube::VERSION
  spec.authors       = ["Reid Beels"]
  spec.email         = ["mail@reidbeels.com"]

  spec.summary       = %q{Provides YouTube storage for the Shrine file upload framework.}
  spec.homepage      = "https://github.com/reidab/shrine-storage-you_tube"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'shrine', '~> 1.1'
  spec.add_dependency 'google-api-client', '~> 0.9.1'

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "vcr", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 1.22.0"
  spec.add_development_dependency "dotenv", "~> 2.0"
end
