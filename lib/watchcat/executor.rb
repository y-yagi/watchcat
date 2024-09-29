require_relative "client"

module Watchcat
  class Executor
    def initialize(paths, recursive:, force_polling:, poll_interval:, block:)
      @th = nil
      @paths = paths
      @recursive = recursive
      @force_polling = force_polling
      @poll_interval = poll_interval
      @block = block
    end

    def start
      @th = Thread.new do
        client =
          Client.new(
            paths: @paths,
            recursive: @recursive,
            force_polling: @force_polling,
            poll_interval: @poll_interval,
            callback: @block
          )
        client.run
      end
    end

    def stop
      @th.kill
    end
  end
end
