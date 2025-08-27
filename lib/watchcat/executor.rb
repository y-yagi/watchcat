require_relative "event"

module Watchcat
  class Executor
    def initialize(paths, recursive:, force_polling:, poll_interval:, filters:, debounce:, block:)
      @paths = paths
      @recursive = recursive
      @force_polling = force_polling
      @poll_interval = poll_interval
      @filters = filters || {}
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
        ignore_remove: @filters[:ignore_remove],
        ignore_access: @filters[:ignore_access],
        ignore_create: @filters[:ignore_create],
        ignore_modify: @filters[:ignore_modify],
        debounce: @debounce
      ) do |kind, paths, raw_kind|
        break if @stop_requested

        event = Watchcat::Event.new(kind, paths, raw_kind)
        @block.call(event)
      end
    end
  end
end
