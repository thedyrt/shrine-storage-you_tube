# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'shrine/storage/you_tube/version'

Gem::Specification.new do |spec|
  spec.name          = 'shrine-storage-you_tube'
  spec.version       = Shrine::Storage::YouTube::VERSION
  spec.authors       = ['Reid Beels', 'The Dyrt']
  spec.email         = ['reid@thedyrt.com']

  spec.summary       = 'Provides YouTube storage for the Shrine file upload framework.'
  spec.homepage      = 'https://github.com/thedyrt/shrine-storage-you_tube'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'google-api-client', '> 0.11'
  spec.add_dependency 'shrine', '> 2.0', '< 4.0'

  spec.add_development_dependency 'appraisal'
  spec.add_development_dependency 'dotenv', '~> 2.0'
  spec.add_development_dependency 'rake', '>= 10.0'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'vcr', '~> 3.0'
  spec.add_development_dependency 'webmock', '~> 2.3'
end
