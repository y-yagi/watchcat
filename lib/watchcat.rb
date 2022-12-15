require_relative "watchcat/version"
require "watchcat/watchcat"
require "thread"

module Watchcat
  def self.watch(path, recursive: false, &block)
    executor = Executor.new
    executor.execute(path, recursive: recursive, &block)
    executor
  end

  class Executor
    def execute(path, recursive: false, &block)
      Thread.new do
        raw_watch(path, recursive: recursive, &block)
      end
    end

    def close
      raw_close
    end
  end
end
