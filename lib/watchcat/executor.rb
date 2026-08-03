require_relative "event"

module Watchcat
  class Executor
    def initialize(paths, recursive:, force_polling:, poll_interval:, filters:, debounce:, block:, patterns: [], ignore_patterns: [], ignore_directories: false)
      @paths = paths
      @recursive = recursive
      @force_polling = force_polling
      @poll_interval = poll_interval
      @filters = filters || {}
      @debounce = debounce
      @debouncer = Debouncer.new if @debounce > 0
      @patterns = Array(patterns)
      @ignore_patterns = Array(ignore_patterns)
      @ignore_directories = ignore_directories
      @block = block
      @watcher = Watchcat::Watcher.new
      @watch_thread = nil
      @stop_requested = false
      @owner_pid = nil
      @stopped = false
    end

    def start
      @owner_pid = Process.pid

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
      # A forked child inherits the at_exit hook without inheriting the watcher
      # thread, so it would call #close -- which sends on a channel, and a send
      # can allocate. If the watcher thread held the allocator lock at fork
      # time, that lock is never released in the child.
      return if @owner_pid != Process.pid

      return if @stopped
      @stopped = true

      @stop_requested = true
      @watcher.close
      if @watch_thread && @watch_thread.alive?
        @watch_thread.join(1) # Wait up to 1 second for thread to finish
      end
    end

    def watch(paths, recursive: @recursive)
      paths = Array(paths)
      paths.each { |p| raise ArgumentError, "path does not exist: #{p}" unless File.exist?(p) }
      @watcher.add(paths, recursive: recursive)
      @paths |= paths
      self
    end

    def unwatch(paths)
      paths = Array(paths)
      @watcher.unwatch(paths)
      @paths -= paths
      self
    end

    def watched
      @paths.dup
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
        ignore_modify: @filters[:ignore_modify]
      ) do |kind, paths, raw_kind|
        next if @stop_requested

        event = Watchcat::Event.new(kind, paths, raw_kind)
        next unless dispatch?(event)

        if @debounce > 0 && paths.size == 1
          @debouncer.debounce(paths[0], @debounce) { @block.call(event) }
        else
          @block.call(event)
        end
      end
    end

    def dispatch?(event)
      return false if @ignore_directories && event.directory?
      return false if @patterns.any? && !matches_any_pattern?(event.paths, @patterns)
      return false if @ignore_patterns.any? && matches_any_pattern?(event.paths, @ignore_patterns)

      true
    end

    def matches_any_pattern?(paths, patterns)
      paths.any? do |path|
        patterns.any? { |pattern| File.fnmatch?(pattern, File.basename(path)) || File.fnmatch?(pattern, path) }
      end
    end
  end
end
