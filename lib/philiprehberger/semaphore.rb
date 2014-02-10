# frozen_string_literal: true

require_relative 'semaphore/version'

module Philiprehberger
  module Semaphore
    class Error < StandardError; end

    # Counting semaphore for concurrent access control with timeouts
    #
    # @example
    #   sem = Philiprehberger::Semaphore::Counter.new(permits: 3)
    #   sem.acquire { do_work }
    class Counter
      # Create a new counting semaphore
      #
      # @param permits [Integer] the number of permits available
      # @return [Counter]
      def initialize(permits:)
        raise Error, 'permits must be a positive integer' unless permits.is_a?(Integer) && permits.positive?

        @permits = permits
        @available = permits
        @mutex = Mutex.new
        @condition = ConditionVariable.new
      end

      # Return the total number of permits
      #
      # @return [Integer]
      def permits
        @mutex.synchronize { @permits }
      end

      # Return the number of currently available permits
      #
      # @return [Integer]
      def available
        @mutex.synchronize { @available }
      end

      # Acquire a permit, blocking until one is available
      #
      # @yield executes the block while holding the permit
      # @return [Object] the block's return value, or true if no block given
      def acquire
        @mutex.synchronize do
          @condition.wait(@mutex) while @available <= 0
          @available -= 1
        end

        if block_given?
          begin
            yield
          ensure
            release
          end
        else
          true
        end
      end

      # Try to acquire a permit within the given timeout
      #
      # @param timeout [Numeric] maximum seconds to wait
      # @yield executes the block while holding the permit
      # @return [Object, false] the block's return value, or false if timeout expired
      def try_acquire(timeout:)
        deadline = Time.now + timeout
        acquired = false

        @mutex.synchronize do
          loop do
            if @available.positive?
              @available -= 1
              acquired = true
              break
            end

            remaining = deadline - Time.now
            break if remaining <= 0

            @condition.wait(@mutex, remaining)
          end
        end

        return false unless acquired

        if block_given?
          begin
            yield
          ensure
            release
          end
        else
          true
        end
      end

      # Release a permit back to the semaphore
      #
      # @return [void]
      # @raise [Error] if more permits are released than acquired
      def release
        @mutex.synchronize do
          raise Error, 'cannot release more permits than total' if @available >= @permits

          @available += 1
          @condition.signal
        end
      end
    end
  end
end
