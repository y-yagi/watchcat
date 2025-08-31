require_relative "watchcat/version"
require_relative "watchcat/executor"
require_relative "watchcat/debouncer"

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
      &block
    )
      w =
        Watchcat::Executor.new(
          Array(paths),
          recursive: recursive,
          force_polling: force_polling,
          poll_interval: poll_interval,
          filters: filters,
          debounce: debounce,
          block: block
        )
      w.start
      w
    end
  end
end
