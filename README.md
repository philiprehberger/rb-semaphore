# philiprehberger-semaphore

[![Tests](https://github.com/philiprehberger/rb-semaphore/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-semaphore/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-semaphore.svg)](https://rubygems.org/gems/philiprehberger-semaphore)
[![GitHub release](https://img.shields.io/github/v/release/philiprehberger/rb-semaphore)](https://github.com/philiprehberger/rb-semaphore/releases)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-semaphore)](https://github.com/philiprehberger/rb-semaphore/commits/main)
[![License](https://img.shields.io/github/license/philiprehberger/rb-semaphore)](LICENSE)
[![Bug Reports](https://img.shields.io/github/issues/philiprehberger/rb-semaphore/bug)](https://github.com/philiprehberger/rb-semaphore/issues?q=is%3Aissue+is%3Aopen+label%3Abug)
[![Feature Requests](https://img.shields.io/github/issues/philiprehberger/rb-semaphore/enhancement)](https://github.com/philiprehberger/rb-semaphore/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)
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
require "philiprehberger/semaphore"

result = sem.try_acquire(timeout: 5) do
  perform_database_query
end
# result is false if timeout expired
```

### Weighted Permits

```ruby
require "philiprehberger/semaphore"

sem = Philiprehberger::Semaphore::Counter.new(permits: 10)
sem.acquire(weight: 3) { heavy_operation }
```

### FIFO Fairness

```ruby
require "philiprehberger/semaphore"

sem = Philiprehberger::Semaphore::Counter.new(permits: 5, fair: true)
sem.acquire { do_work }
```

### Dynamic Permit Adjustment

```ruby
require "philiprehberger/semaphore"

sem = Philiprehberger::Semaphore::Counter.new(permits: 3)
sem.resize(5)
sem.permits   # => 5
sem.available # => 5
```

## API

| Method | Description |
|--------|-------------|
| `.new(permits:, fair: false)` | Create a semaphore with the given number of permits and optional FIFO fairness |
| `#acquire(weight: 1) { block }` | Acquire one or more permits, blocking until available |
| `#try_acquire(timeout:, weight: 1) { block }` | Try to acquire within timeout, returns false on expiry |
| `#release(weight: 1)` | Release one or more permits back to the semaphore |
| `#resize(new_permits)` | Change total permit count at runtime |
| `#available` | Return the number of currently available permits |
| `#permits` | Return the total number of permits |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this package useful, consider giving it a star on GitHub — it helps motivate continued maintenance and development.

[![LinkedIn](https://img.shields.io/badge/Philip%20Rehberger-LinkedIn-0A66C2?logo=linkedin)](https://www.linkedin.com/in/philiprehberger)
[![More packages](https://img.shields.io/badge/more-open%20source%20packages-blue)](https://philiprehberger.com/open-source-packages)

## License

[MIT](LICENSE)
