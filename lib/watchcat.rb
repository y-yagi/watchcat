require_relative "watchcat/version"
require_relative "watchcat/executor"
require "watchcat/watchcat"

module Watchcat
  class << self
    def watch(paths, recursive: false, &block)
      w = Watchcat::Executor.new(Array(paths), recursive: recursive, block: block)
      w.start
      w
    end
  end
end
