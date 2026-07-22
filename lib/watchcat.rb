require_relative "watchcat/version"
require_relative "watchcat/executor"
require_relative "watchcat/debouncer"
require_relative "watchcat/event_handler"

begin
  require "watchcat/#{RUBY_VERSION.to_f}/watchcat"
rescue LoadError
  require "watchcat/watchcat"
end

module Watchcat
  class << self
    def watch(
      paths,
      recursive: true,
      force_polling: false,
      poll_interval: nil,
      filters: {},
      debounce: -1,
      patterns: [],
      ignore_patterns: [],
      ignore_directories: false,
      handler: nil,
      &block
    )
      callback = block || (handler && handler.method(:dispatch))
      raise ArgumentError, "must provide a block or a handler:" unless callback

      w =
        Watchcat::Executor.new(
          Array(paths),
          recursive: recursive,
          force_polling: force_polling,
          poll_interval: poll_interval,
          filters: filters,
          debounce: debounce,
          patterns: patterns,
          ignore_patterns: ignore_patterns,
          ignore_directories: ignore_directories,
          block: callback
        )
      w.start
      w
    end
  end
end
