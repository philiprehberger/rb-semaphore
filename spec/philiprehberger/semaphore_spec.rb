# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::Semaphore do
  it 'has a version number' do
    expect(described_class::VERSION).not_to be_nil
  end
end

RSpec.describe Philiprehberger::Semaphore::Counter do
  describe '.new' do
    it 'creates a semaphore with the given permits' do
      sem = described_class.new(permits: 3)
      expect(sem.permits).to eq(3)
      expect(sem.available).to eq(3)
    end

    it 'raises for non-positive permits' do
      expect { described_class.new(permits: 0) }.to raise_error(Philiprehberger::Semaphore::Error)
    end

    it 'raises for negative permits' do
      expect { described_class.new(permits: -1) }.to raise_error(Philiprehberger::Semaphore::Error)
    end

    it 'raises for non-integer permits' do
      expect { described_class.new(permits: 'abc') }.to raise_error(Philiprehberger::Semaphore::Error)
    end

    it 'raises for float permits' do
      expect { described_class.new(permits: 1.5) }.to raise_error(Philiprehberger::Semaphore::Error)
    end

    it 'creates a semaphore with a single permit' do
      sem = described_class.new(permits: 1)
      expect(sem.permits).to eq(1)
      expect(sem.available).to eq(1)
    end

    it 'creates a semaphore with many permits' do
      sem = described_class.new(permits: 1000)
      expect(sem.permits).to eq(1000)
    end

    it 'defaults fair to false' do
      sem = described_class.new(permits: 3)
      expect(sem.available).to eq(3)
    end

    it 'accepts fair: true' do
      sem = described_class.new(permits: 3, fair: true)
      expect(sem.permits).to eq(3)
    end
  end

  describe '#acquire' do
    it 'acquires a permit and decrements available' do
      sem = described_class.new(permits: 2)
      sem.acquire {}
      expect(sem.available).to eq(2)
    end

    it 'yields the block while holding the permit' do
      sem = described_class.new(permits: 1)
      result = sem.acquire { 'done' }
      expect(result).to eq('done')
    end

    it 'releases the permit even if the block raises' do
      sem = described_class.new(permits: 1)
      begin
        sem.acquire { raise 'boom' }
      rescue RuntimeError
        nil
      end
      expect(sem.available).to eq(1)
    end

    it 'returns true when no block given' do
      sem = described_class.new(permits: 1)
      expect(sem.acquire).to be true
      sem.release
    end

    it 'blocks when no permits available and resumes after release' do
      sem = described_class.new(permits: 1)
      sem.acquire
      acquired = false

      thread = Thread.new do
        sem.acquire { acquired = true }
      end

      sleep(0.02)
      expect(acquired).to be false
      sem.release
      thread.join(1)
      expect(acquired).to be true
    end

    it 'decrements available count while held without block' do
      sem = described_class.new(permits: 3)
      sem.acquire
      expect(sem.available).to eq(2)
      sem.acquire
      expect(sem.available).to eq(1)
      sem.release
      sem.release
    end

    it 'returns block return value' do
      sem = described_class.new(permits: 1)
      result = sem.acquire { 42 }
      expect(result).to eq(42)
    end

    it 'supports nested acquire with multiple permits' do
      sem = described_class.new(permits: 2)
      result = sem.acquire do
        inner = sem.acquire { 'inner' }
        "outer-#{inner}"
      end
      expect(result).to eq('outer-inner')
    end
  end

  describe '#acquire with weight' do
    it 'acquires multiple permits at once' do
      sem = described_class.new(permits: 5)
      sem.acquire(weight: 3) {}
      expect(sem.available).to eq(5)
    end

    it 'decrements available by the weight' do
      sem = described_class.new(permits: 5)
      sem.acquire(weight: 3)
      expect(sem.available).to eq(2)
      sem.release(weight: 3)
    end

    it 'blocks until enough permits are available' do
      sem = described_class.new(permits: 3)
      sem.acquire(weight: 2)
      acquired = false

      thread = Thread.new do
        sem.acquire(weight: 2) { acquired = true }
      end

      sleep(0.02)
      expect(acquired).to be false
      sem.release(weight: 2)
      thread.join(1)
      expect(acquired).to be true
    end

    it 'raises ArgumentError for weight less than 1' do
      sem = described_class.new(permits: 5)
      expect { sem.acquire(weight: 0) }.to raise_error(ArgumentError, /weight must be a positive integer/)
    end

    it 'raises ArgumentError for negative weight' do
      sem = described_class.new(permits: 5)
      expect { sem.acquire(weight: -1) }.to raise_error(ArgumentError, /weight must be a positive integer/)
    end

    it 'raises ArgumentError for weight exceeding total permits' do
      sem = described_class.new(permits: 3)
      expect { sem.acquire(weight: 4) }.to raise_error(ArgumentError, /weight cannot exceed total permits/)
    end

    it 'raises ArgumentError for non-integer weight' do
      sem = described_class.new(permits: 5)
      expect { sem.acquire(weight: 1.5) }.to raise_error(ArgumentError, /weight must be a positive integer/)
    end

    it 'defaults weight to 1' do
      sem = described_class.new(permits: 3)
      sem.acquire
      expect(sem.available).to eq(2)
      sem.release
    end

    it 'releases the correct weight even if the block raises' do
      sem = described_class.new(permits: 5)
      begin
        sem.acquire(weight: 3) { raise 'boom' }
      rescue RuntimeError
        nil
      end
      expect(sem.available).to eq(5)
    end

    it 'returns true when no block given with weight' do
      sem = described_class.new(permits: 5)
      expect(sem.acquire(weight: 3)).to be true
      sem.release(weight: 3)
    end
  end

  describe '#try_acquire' do
    it 'acquires a permit when available' do
      sem = described_class.new(permits: 1)
      result = sem.try_acquire(timeout: 1) { 'ok' }
      expect(result).to eq('ok')
    end

    it 'returns false when timeout expires' do
      sem = described_class.new(permits: 1)
      sem.acquire
      result = sem.try_acquire(timeout: 0.01) { 'ok' }
      expect(result).to be false
      sem.release
    end

    it 'releases the permit even if the block raises' do
      sem = described_class.new(permits: 1)
      begin
        sem.try_acquire(timeout: 1) { raise 'boom' }
      rescue RuntimeError
        nil
      end
      expect(sem.available).to eq(1)
    end

    it 'returns true when no block given' do
      sem = described_class.new(permits: 1)
      expect(sem.try_acquire(timeout: 1)).to be true
      sem.release
    end

    it 'acquires if permit becomes available before timeout' do
      sem = described_class.new(permits: 1)
      sem.acquire

      thread = Thread.new do
        sleep(0.05)
        sem.release
      end

      result = sem.try_acquire(timeout: 2) { 'acquired' }
      thread.join
      expect(result).to eq('acquired')
    end

    it 'returns false immediately with zero timeout when no permits' do
      sem = described_class.new(permits: 1)
      sem.acquire
      result = sem.try_acquire(timeout: 0) { 'ok' }
      expect(result).to be false
      sem.release
    end

    it 'succeeds immediately when permits are available' do
      sem = described_class.new(permits: 5)
      result = sem.try_acquire(timeout: 0) { 'ok' }
      expect(result).to eq('ok')
    end
  end

  describe '#try_acquire with weight' do
    it 'acquires multiple permits within timeout' do
      sem = described_class.new(permits: 5)
      result = sem.try_acquire(timeout: 1, weight: 3) { 'ok' }
      expect(result).to eq('ok')
    end

    it 'returns false when not enough permits become available' do
      sem = described_class.new(permits: 3)
      sem.acquire(weight: 2)
      result = sem.try_acquire(timeout: 0.01, weight: 2) { 'ok' }
      expect(result).to be false
      sem.release(weight: 2)
    end

    it 'acquires when enough permits are released before timeout' do
      sem = described_class.new(permits: 4)
      sem.acquire(weight: 3)

      thread = Thread.new do
        sleep(0.05)
        sem.release(weight: 3)
      end

      result = sem.try_acquire(timeout: 2, weight: 3) { 'acquired' }
      thread.join
      expect(result).to eq('acquired')
    end

    it 'raises ArgumentError for weight exceeding total' do
      sem = described_class.new(permits: 3)
      expect { sem.try_acquire(timeout: 1, weight: 4) }.to raise_error(ArgumentError, /weight cannot exceed total permits/)
    end

    it 'releases correct weight even if block raises' do
      sem = described_class.new(permits: 5)
      begin
        sem.try_acquire(timeout: 1, weight: 3) { raise 'boom' }
      rescue RuntimeError
        nil
      end
      expect(sem.available).to eq(5)
    end
  end

  describe '#release' do
    it 'raises when releasing more permits than total' do
      sem = described_class.new(permits: 1)
      expect { sem.release }.to raise_error(Philiprehberger::Semaphore::Error)
    end

    it 'raises with descriptive message' do
      sem = described_class.new(permits: 1)
      expect { sem.release }.to raise_error(Philiprehberger::Semaphore::Error, /cannot release more permits than total/)
    end

    it 'increments available count' do
      sem = described_class.new(permits: 2)
      sem.acquire
      sem.acquire
      expect(sem.available).to eq(0)
      sem.release
      expect(sem.available).to eq(1)
      sem.release
      expect(sem.available).to eq(2)
    end

    it 'raises when releasing weight that would exceed total' do
      sem = described_class.new(permits: 5)
      sem.acquire(weight: 2)
      expect { sem.release(weight: 4) }.to raise_error(Philiprehberger::Semaphore::Error)
    end

    it 'raises ArgumentError for invalid weight on release' do
      sem = described_class.new(permits: 5)
      sem.acquire
      expect { sem.release(weight: 0) }.to raise_error(ArgumentError)
    end
  end

  describe '#permits' do
    it 'returns the total number of permits' do
      sem = described_class.new(permits: 5)
      sem.acquire
      expect(sem.permits).to eq(5)
      sem.release
    end
  end

  describe '#available' do
    it 'reflects current available permits' do
      sem = described_class.new(permits: 3)
      expect(sem.available).to eq(3)
      sem.acquire
      expect(sem.available).to eq(2)
      sem.release
      expect(sem.available).to eq(3)
    end
  end

  describe '#resize' do
    it 'increases total permits' do
      sem = described_class.new(permits: 3)
      sem.resize(5)
      expect(sem.permits).to eq(5)
      expect(sem.available).to eq(5)
    end

    it 'decreases total permits' do
      sem = described_class.new(permits: 5)
      sem.resize(3)
      expect(sem.permits).to eq(3)
      expect(sem.available).to eq(3)
    end

    it 'wakes blocked threads when permits increase' do
      sem = described_class.new(permits: 1)
      sem.acquire
      acquired = false

      thread = Thread.new do
        sem.acquire { acquired = true }
      end

      sleep(0.02)
      expect(acquired).to be false
      sem.resize(2)
      thread.join(1)
      expect(acquired).to be true
      sem.release
    end

    it 'does not interrupt currently held permits on decrease' do
      sem = described_class.new(permits: 5)
      sem.acquire(weight: 3)
      sem.resize(2)
      expect(sem.permits).to eq(2)
      expect(sem.available).to eq(-1)
      sem.release(weight: 1)
      expect(sem.available).to eq(0)
      sem.release(weight: 1)
      expect(sem.available).to eq(1)
      sem.release(weight: 1)
      expect(sem.available).to eq(2)
    end

    it 'raises for non-positive new permits' do
      sem = described_class.new(permits: 3)
      expect { sem.resize(0) }.to raise_error(Philiprehberger::Semaphore::Error)
    end

    it 'raises for negative new permits' do
      sem = described_class.new(permits: 3)
      expect { sem.resize(-1) }.to raise_error(Philiprehberger::Semaphore::Error)
    end

    it 'raises for non-integer new permits' do
      sem = described_class.new(permits: 3)
      expect { sem.resize(2.5) }.to raise_error(Philiprehberger::Semaphore::Error)
    end

    it 'allows resize to the same value' do
      sem = described_class.new(permits: 3)
      sem.resize(3)
      expect(sem.permits).to eq(3)
      expect(sem.available).to eq(3)
    end

    it 'updates available correctly after acquire and resize' do
      sem = described_class.new(permits: 5)
      sem.acquire(weight: 2)
      expect(sem.available).to eq(3)
      sem.resize(8)
      expect(sem.permits).to eq(8)
      expect(sem.available).to eq(6)
      sem.release(weight: 2)
      expect(sem.available).to eq(8)
    end
  end

  describe 'FIFO fairness (fair: true)' do
    it 'creates a fair semaphore' do
      sem = described_class.new(permits: 1, fair: true)
      expect(sem.permits).to eq(1)
    end

    it 'acquires and releases permits normally' do
      sem = described_class.new(permits: 2, fair: true)
      result = sem.acquire { 'done' }
      expect(result).to eq('done')
      expect(sem.available).to eq(2)
    end

    it 'guarantees FIFO ordering for waiters' do
      sem = described_class.new(permits: 1, fair: true)
      sem.acquire
      order = []
      mutex = Mutex.new

      threads = 3.times.map do |i|
        Thread.new do
          sleep(0.01 * (i + 1))
          sem.acquire do
            mutex.synchronize { order << i }
          end
        end
      end

      sleep(0.06)
      sem.release

      threads.each { |t| t.join(3) }
      expect(order).to eq([0, 1, 2])
    end

    it 'supports try_acquire with fairness' do
      sem = described_class.new(permits: 1, fair: true)
      result = sem.try_acquire(timeout: 1) { 'ok' }
      expect(result).to eq('ok')
    end

    it 'returns false on try_acquire timeout with fairness' do
      sem = described_class.new(permits: 1, fair: true)
      sem.acquire
      result = sem.try_acquire(timeout: 0.01) { 'ok' }
      expect(result).to be false
      sem.release
    end

    it 'supports weighted acquire with fairness' do
      sem = described_class.new(permits: 5, fair: true)
      result = sem.acquire(weight: 3) { 'ok' }
      expect(result).to eq('ok')
      expect(sem.available).to eq(5)
    end

    it 'supports resize with fairness' do
      sem = described_class.new(permits: 1, fair: true)
      sem.acquire
      acquired = false

      thread = Thread.new do
        sem.acquire { acquired = true }
      end

      sleep(0.02)
      expect(acquired).to be false
      sem.resize(2)
      thread.join(1)
      expect(acquired).to be true
      sem.release
    end

    it 'releases permit even if block raises under fair mode' do
      sem = described_class.new(permits: 1, fair: true)
      begin
        sem.acquire { raise 'boom' }
      rescue RuntimeError
        nil
      end
      expect(sem.available).to eq(1)
    end
  end

  describe '#fair?' do
    it 'returns false by default' do
      sem = described_class.new(permits: 3)
      expect(sem.fair?).to be false
    end

    it 'returns true when created with fair: true' do
      sem = described_class.new(permits: 3, fair: true)
      expect(sem.fair?).to be true
    end
  end

  describe '#draining?' do
    it 'returns false initially' do
      sem = described_class.new(permits: 3)
      expect(sem.draining?).to be false
    end

    it 'returns true after drain is called' do
      sem = described_class.new(permits: 3)
      sem.drain
      expect(sem.draining?).to be true
    end
  end

  describe '#drain' do
    it 'completes immediately when no permits are held' do
      sem = described_class.new(permits: 3)
      sem.drain
      expect(sem.draining?).to be true
      expect(sem.available).to eq(3)
    end

    it 'blocks until all permits are returned' do
      sem = described_class.new(permits: 2)
      sem.acquire
      drained = false

      drain_thread = Thread.new do
        sem.drain
        drained = true
      end

      sleep(0.02)
      expect(drained).to be false
      sem.release
      drain_thread.join(1)
      expect(drained).to be true
    end

    it 'blocks until weighted permits are returned' do
      sem = described_class.new(permits: 5)
      sem.acquire(weight: 3)
      drained = false

      drain_thread = Thread.new do
        sem.drain
        drained = true
      end

      sleep(0.02)
      expect(drained).to be false
      sem.release(weight: 3)
      drain_thread.join(1)
      expect(drained).to be true
    end

    it 'is idempotent' do
      sem = described_class.new(permits: 1)
      sem.drain
      sem.drain
      expect(sem.draining?).to be true
    end

    it 'wakes blocked acquirers who then raise' do
      sem = described_class.new(permits: 1)
      sem.acquire
      error_raised = false

      waiter = Thread.new do
        sem.acquire { 'should not run' }
      rescue Philiprehberger::Semaphore::Error
        error_raised = true
      end

      sleep(0.02)
      Thread.new { sem.drain }
      sleep(0.02)
      sem.release
      waiter.join(1)
      expect(error_raised).to be true
    end

    it 'works with fair mode' do
      sem = described_class.new(permits: 2, fair: true)
      sem.acquire
      drained = false

      drain_thread = Thread.new do
        sem.drain
        drained = true
      end

      sleep(0.02)
      expect(drained).to be false
      sem.release
      drain_thread.join(1)
      expect(drained).to be true
    end

    it 'wakes fair-mode blocked acquirers who then raise' do
      sem = described_class.new(permits: 1, fair: true)
      sem.acquire
      error_raised = false

      waiter = Thread.new do
        sem.acquire { 'should not run' }
      rescue Philiprehberger::Semaphore::Error
        error_raised = true
      end

      sleep(0.02)
      Thread.new { sem.drain }
      sleep(0.02)
      sem.release
      waiter.join(1)
      expect(error_raised).to be true
    end
  end

  describe 'acquire during drain' do
    it 'raises on acquire when draining' do
      sem = described_class.new(permits: 3)
      sem.drain
      expect { sem.acquire }.to raise_error(Philiprehberger::Semaphore::Error, /draining/)
    end

    it 'raises on acquire with block when draining' do
      sem = described_class.new(permits: 3)
      sem.drain
      expect { sem.acquire { 'nope' } }.to raise_error(Philiprehberger::Semaphore::Error, /draining/)
    end

    it 'returns false on try_acquire when draining' do
      sem = described_class.new(permits: 3)
      sem.drain
      result = sem.try_acquire(timeout: 1) { 'nope' }
      expect(result).to be false
    end

    it 'raises on acquire in fair mode when draining' do
      sem = described_class.new(permits: 3, fair: true)
      sem.drain
      expect { sem.acquire }.to raise_error(Philiprehberger::Semaphore::Error, /draining/)
    end

    it 'returns false on try_acquire in fair mode when draining' do
      sem = described_class.new(permits: 3, fair: true)
      sem.drain
      result = sem.try_acquire(timeout: 1) { 'nope' }
      expect(result).to be false
    end
  end

  describe 'concurrent access' do
    it 'limits concurrent access to the number of permits' do
      sem = described_class.new(permits: 2)
      concurrent = 0
      max_concurrent = 0
      mutex = Mutex.new

      threads = 5.times.map do
        Thread.new do
          sem.acquire do
            mutex.synchronize do
              concurrent += 1
              max_concurrent = [max_concurrent, concurrent].max
            end
            sleep(0.01)
            mutex.synchronize { concurrent -= 1 }
          end
        end
      end

      threads.each { |t| t.join(5) }
      expect(max_concurrent).to be <= 2
    end

    it 'enforces single-permit mutual exclusion' do
      sem = described_class.new(permits: 1)
      concurrent = 0
      max_concurrent = 0
      mutex = Mutex.new

      threads = 5.times.map do
        Thread.new do
          sem.acquire do
            mutex.synchronize do
              concurrent += 1
              max_concurrent = [max_concurrent, concurrent].max
            end
            sleep(0.01)
            mutex.synchronize { concurrent -= 1 }
          end
        end
      end

      threads.each { |t| t.join(5) }
      expect(max_concurrent).to eq(1)
    end

    it 'processes all threads even under contention' do
      sem = described_class.new(permits: 2)
      completed = 0
      mutex = Mutex.new

      threads = 10.times.map do
        Thread.new do
          sem.acquire do
            sleep(0.01)
            mutex.synchronize { completed += 1 }
          end
        end
      end

      threads.each { |t| t.join(5) }
      expect(completed).to eq(10)
    end

    it 'limits concurrent access with weighted permits' do
      sem = described_class.new(permits: 4)
      concurrent_weight = 0
      max_concurrent_weight = 0
      mutex = Mutex.new

      threads = 6.times.map do
        Thread.new do
          sem.acquire(weight: 2) do
            mutex.synchronize do
              concurrent_weight += 2
              max_concurrent_weight = [max_concurrent_weight, concurrent_weight].max
            end
            sleep(0.01)
            mutex.synchronize { concurrent_weight -= 2 }
          end
        end
      end

      threads.each { |t| t.join(5) }
      expect(max_concurrent_weight).to be <= 4
    end

    it 'processes all threads under fair mode' do
      sem = described_class.new(permits: 2, fair: true)
      completed = 0
      mutex = Mutex.new

      threads = 8.times.map do
        Thread.new do
          sem.acquire do
            sleep(0.01)
            mutex.synchronize { completed += 1 }
          end
        end
      end

      threads.each { |t| t.join(5) }
      expect(completed).to eq(8)
    end
  end
end
