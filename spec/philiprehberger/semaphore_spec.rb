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
  end
end
