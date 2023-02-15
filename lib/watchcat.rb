require_relative "watchcat/version"
require_relative "watchcat/executor"
require "watchcat/watchcat"

module Watchcat
  class << self
    def watch(path, recursive: false, &block)
      w = Watchcat::Executor.new(path, recursive: recursive, block: block)
      w.start
      w
    end
  end
end
