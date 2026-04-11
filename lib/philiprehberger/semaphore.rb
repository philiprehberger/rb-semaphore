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
      # @param fair [Boolean] when true, guarantee FIFO ordering for waiters
      # @return [Counter]
      def initialize(permits:, fair: false)
        raise Error, 'permits must be a positive integer' unless permits.is_a?(Integer) && permits.positive?

        @permits = permits
        @available = permits
        @mutex = Mutex.new
        @fair = fair
        @draining = false
        @drain_condition = ConditionVariable.new

        if @fair
          @queue = []
        else
          @condition = ConditionVariable.new
        end
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

      # Return whether this semaphore uses FIFO fairness
      #
      # @return [Boolean]
      def fair?
        @fair
      end

      # Return whether this semaphore is currently draining
      #
      # @return [Boolean]
      def draining?
        @mutex.synchronize { @draining }
      end

      # Drain the semaphore: reject new acquisitions and block until all permits are returned
      #
      # Once draining begins, {#acquire} raises {Error} and {#try_acquire} returns false.
      # This method blocks the calling thread until every outstanding permit has been released.
      # After drain completes the semaphore remains in the draining state.
      #
      # @return [void]
      def drain
        @mutex.synchronize do
          @draining = true

          # Wake all waiting acquirers so they can observe the draining state and exit
          if @fair
            @queue.each(&:signal)
          else
            @condition.broadcast
          end

          @drain_condition.wait(@mutex) while @available < @permits
        end
      end

      # Acquire one or more permits, blocking until available
      #
      # @param weight [Integer] number of permits to acquire (default: 1)
      # @yield executes the block while holding the permit(s)
      # @return [Object] the block's return value, or true if no block given
      def acquire(weight: 1)
        validate_weight!(weight)

        @mutex.synchronize do
          raise Error, 'semaphore is draining' if @draining

          if @fair
            cv = ConditionVariable.new
            @queue.push(cv)
            loop do
              raise_if_draining_fair!(cv)
              break if @queue.first == cv && @available >= weight

              cv.wait(@mutex)
            end
            @queue.shift
          else
            loop do
              raise Error, 'semaphore is draining' if @draining
              break if @available >= weight

              @condition.wait(@mutex)
            end
          end
          @available -= weight
        end

        if block_given?
          begin
            yield
          ensure
            release(weight: weight)
          end
        else
          true
        end
      end

      # Try to acquire one or more permits within the given timeout
      #
      # @param timeout [Numeric] maximum seconds to wait
      # @param weight [Integer] number of permits to acquire (default: 1)
      # @yield executes the block while holding the permit(s)
      # @return [Object, false] the block's return value, or false if timeout expired
      def try_acquire(timeout:, weight: 1)
        validate_weight!(weight)
        deadline = Time.now + timeout
        acquired = false

        @mutex.synchronize do
          return false if @draining

          if @fair
            cv = ConditionVariable.new
            @queue.push(cv)

            loop do
              if @draining
                @queue.delete(cv)
                break
              end

              if @queue.first == cv && @available >= weight
                @queue.shift
                acquired = true
                break
              end

              remaining = deadline - Time.now
              if remaining <= 0
                @queue.delete(cv)
                break
              end

              cv.wait(@mutex, remaining)
            end
          else
            loop do
              break if @draining

              if @available >= weight
                acquired = true
                break
              end

              remaining = deadline - Time.now
              break if remaining <= 0

              @condition.wait(@mutex, remaining)
            end
          end

          @available -= weight if acquired
        end

        return false unless acquired

        if block_given?
          begin
            yield
          ensure
            release(weight: weight)
          end
        else
          true
        end
      end

      # Release one or more permits back to the semaphore
      #
      # @param weight [Integer] number of permits to release (default: 1)
      # @return [void]
      # @raise [Error] if more permits are released than acquired
      def release(weight: 1)
        validate_weight!(weight)

        @mutex.synchronize do
          raise Error, 'cannot release more permits than total' if @available + weight > @permits

          @available += weight

          if @draining
            @drain_condition.signal if @available >= @permits
          elsif @fair
            @queue.each(&:signal)
          else
            weight.times { @condition.signal }
          end
        end
      end

      # Resize the semaphore to a new total permit count
      #
      # @param new_permits [Integer] the new total number of permits
      # @return [void]
      # @raise [Error] if new_permits is not a positive integer
      def resize(new_permits)
        raise Error, 'permits must be a positive integer' unless new_permits.is_a?(Integer) && new_permits.positive?

        @mutex.synchronize do
          diff = new_permits - @permits
          @permits = new_permits
          @available += diff

          # If permits increased, wake waiters that may now be able to acquire
          if diff.positive?
            if @fair
              @queue.each(&:signal)
            else
              diff.times { @condition.signal }
            end
          end
        end
      end

      private

      def validate_weight!(weight)
        raise ArgumentError, 'weight must be a positive integer' unless weight.is_a?(Integer) && weight >= 1
        raise ArgumentError, 'weight cannot exceed total permits' if weight > @mutex.synchronize { @permits }
      end

      def raise_if_draining_fair!(cv)
        return unless @draining

        @queue.delete(cv)
        raise Error, 'semaphore is draining'
      end
    end
  end
end
