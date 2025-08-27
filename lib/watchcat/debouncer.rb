module Watchcat
  class Debouncer
    def initialize
      @timers = {}
      @mutex = Mutex.new
    end

    def debounce(key, delay_ms, &block)
      @mutex.synchronize do
        # Cancel existing timer for this key
        if @timers[key]
          @timers[key].kill
        end

        # Create new timer
        @timers[key] = Thread.new do
          sleep(delay_ms / 1000.0)  # Convert ms to seconds

          @mutex.synchronize do
            @timers.delete(key)
          end

          block.call
        end
      end
    end

    def clear
      @mutex.synchronize do
        @timers.each_value(&:kill)
        @timers.clear
      end
    end

    def pending_count
      @mutex.synchronize do
        @timers.size
      end
    end
  end
end
