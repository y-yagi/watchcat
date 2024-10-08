require "drb"
require "drb/unix"
require_relative "server"
require_relative "client"

module Watchcat
  class Executor
    def initialize(paths, recursive:, force_polling:, poll_interval:, wait_until_startup:, block:)
      @service = nil
      @child_pid = nil
      @paths = paths
      @recursive = recursive
      @force_polling = force_polling
      @poll_interval = poll_interval
      @wait_until_startup = wait_until_startup
      @block = block
    end

    def start
      server = Server.new(@block)
      @service = DRb.start_service("drbunix:", server)
      client = nil
      client = build_client if @wait_until_startup

      @child_pid = fork do
        client = build_client unless @wait_until_startup
        Process.setproctitle("watchcat: watcher")
        client.run
      end
    end

    def stop
      Process.kill(:KILL, @child_pid)
      @service.stop_service
    end

    private

    def build_client
      Client.new(
        @service.uri,
        paths: @paths,
        recursive: @recursive,
        force_polling: @force_polling,
        poll_interval: @poll_interval
      )
    end
  end
end
