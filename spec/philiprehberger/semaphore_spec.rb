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
  end

  describe '#release' do
    it 'raises when releasing more permits than total' do
      sem = described_class.new(permits: 1)
      expect { sem.release }.to raise_error(Philiprehberger::Semaphore::Error)
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
  end
end
