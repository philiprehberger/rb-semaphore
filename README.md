# philiprehberger-semaphore

[![Tests](https://github.com/philiprehberger/rb-semaphore/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-semaphore/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-semaphore.svg)](https://rubygems.org/gems/philiprehberger-semaphore)
[![License](https://img.shields.io/github/license/philiprehberger/rb-semaphore)](LICENSE)
[![Sponsor](https://img.shields.io/badge/sponsor-GitHub%20Sponsors-ec6cb9)](https://github.com/sponsors/philiprehberger)

Counting semaphore for concurrent access control with timeouts

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-semaphore"
```

Or install directly:

```bash
gem install philiprehberger-semaphore
```

## Usage

```ruby
require "philiprehberger/semaphore"

sem = Philiprehberger::Semaphore::Counter.new(permits: 3)
sem.acquire { do_work }
```

### Timeout-Based Acquisition

```ruby
result = sem.try_acquire(timeout: 5) do
  perform_database_query
end
# result is false if timeout expired
```

### Checking Availability

```ruby
sem.available # => number of free permits
sem.permits   # => total permits
```

## API

| Method | Description |
|--------|-------------|
| `.new(permits:)` | Create a semaphore with the given number of permits |
| `#acquire { block }` | Acquire a permit, blocking until available |
| `#try_acquire(timeout:) { block }` | Try to acquire within timeout, returns false on expiry |
| `#release` | Release a permit back to the semaphore |
| `#available` | Return the number of currently available permits |
| `#permits` | Return the total number of permits |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
