require "drb"
require "drb/unix"
require_relative "server"
require_relative "client"

module Watchcat
  class Executor
    def initialize(paths, recursive:, force_polling:, poll_interval:, block:)
      @service = nil
      @child_pid = nil
      @paths = paths
      @recursive = recursive
      @force_polling = force_polling
      @poll_interval = poll_interval
      @block = block
    end

    def start
      server = Server.new(@block)
      @service = DRb.start_service("drbunix:", server)
      @child_pid =
        fork do
          Process.setproctitle("watchcat: watcher")
          client =
            Client.new(
              @service.uri,
              paths: @paths,
              recursive: @recursive,
              force_polling: @force_polling,
              poll_interval: @poll_interval
            )
          client.run
        end
    end

    def stop
      Process.kill(:KILL, @child_pid)
      @service.stop_service
    end
  end
end
