# frozen_string_literal: true

require_relative 'lib/philiprehberger/semaphore/version'

Gem::Specification.new do |spec|
  spec.name          = 'philiprehberger-semaphore'
  spec.version       = Philiprehberger::Semaphore::VERSION
  spec.authors       = ['Philip Rehberger']
  spec.email         = ['me@philiprehberger.com']

  spec.summary       = 'Counting semaphore for concurrent access control with timeouts'
  spec.description   = 'Counting semaphore built on Mutex and ConditionVariable for concurrent access control ' \
                       'with configurable permits, weighted acquisition, FIFO fairness, dynamic resizing, ' \
                       'blocking acquire, and timeout-based try_acquire.'
  spec.homepage      = 'https://github.com/philiprehberger/rb-semaphore'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = spec.homepage
  spec.metadata['changelog_uri']         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri']       = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
