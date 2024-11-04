require_relative "watchcat/version"
require_relative "watchcat/executor"

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
      wait_until_startup: false,
      ignore_remove: false,
      debounce: -1,
      &block
    )
      w =
        Watchcat::Executor.new(
          Array(paths),
          recursive: recursive,
          force_polling: force_polling,
          poll_interval: poll_interval,
          wait_until_startup: wait_until_startup,
          ignore_remove: ignore_remove,
          debounce: debounce,
          block: block
        )
      w.start
      w
    end
  end
end
