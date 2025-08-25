require_relative "event"

module Watchcat
  class Executor
    def initialize(paths, recursive:, force_polling:, poll_interval:, wait_until_startup:, filters:, debounce:, block:)
      @paths = paths
      @recursive = recursive
      @force_polling = force_polling
      @poll_interval = poll_interval
      @wait_until_startup = wait_until_startup
      @filters = filters || {}
      @ignore_remove = @filters[:ignore_remove]
      @debounce = debounce
      @block = block
      @watcher = Watchcat::Watcher.new
      @watch_thread = nil
      @stop_requested = false
    end

    def start
      # Always start watching in a background thread to avoid blocking
      @watch_thread = Thread.new do
        Thread.current.name = "watchcat-watcher"
        start_watching
      end

      # If wait_until_startup is true, give the thread a moment to start
      if @wait_until_startup
        sleep 0.1
      end

      at_exit do
        stop
      end
    end

    def stop
      @stop_requested = true
      @watcher.close
      if @watch_thread && @watch_thread.alive?
        @watch_thread.join(1) # Wait up to 1 second for thread to finish
      end
    end

    private

    def start_watching
      @watcher.watch(
        @paths,
        recursive: @recursive,
        force_polling: @force_polling,
        poll_interval: @poll_interval,
        ignore_remove: @ignore_remove,
        debounce: @debounce
      ) do |kind, paths, raw_kind|
        break if @stop_requested

        # Create an event object and call the block
        event = Watchcat::Event.new(kind, paths, raw_kind)
        @block.call(event)
      end
    end
  end
end
