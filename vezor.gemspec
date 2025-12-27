# frozen_string_literal: true

require_relative 'lib/vezor/version'

Gem::Specification.new do |spec|
  spec.name          = 'vezor'
  spec.version       = Vezor::VERSION
  spec.authors       = ['Vezor Team']
  spec.email         = ['hello@vezor.io']

  spec.summary       = 'GitOps-native secrets management SDK'
  spec.description   = 'A Ruby SDK for interacting with the Vezor secrets management platform. ' \
                       'Manage secrets, tags, groups, and more with a clean API.'
  spec.homepage      = 'https://github.com/vezor/vezor-ruby'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/vezor/vezor-ruby'
  spec.metadata['changelog_uri'] = 'https://github.com/vezor/vezor-ruby/blob/main/CHANGELOG.md'

  spec.files = Dir.chdir(__dir__) do
    Dir['{lib}/**/*', 'LICENSE', 'README.md', 'CHANGELOG.md'].reject { |f| File.directory?(f) }
  end

  spec.require_paths = ['lib']

  # No runtime dependencies - uses only Ruby stdlib (net/http, json, uri)
end
