require "drb"
require "drb/unix"
require_relative "server"
require_relative "client"

module Watchcat
  class Executor
    def initialize(paths, recursive:, force_polling:, poll_interval:, wait_until_startup:, ignore_remove:, debounce:, block:)
      @service = nil
      @child_pid = nil
      @paths = paths
      @recursive = recursive
      @force_polling = force_polling
      @poll_interval = poll_interval
      @wait_until_startup = wait_until_startup
      @ignore_remove = ignore_remove
      @debounce = debounce
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

      main = Process.pid
      at_exit do
        @exit_status = $!.status if $!.is_a?(SystemExit)
        stop if Process.pid == main
        exit @exit_status if @exit_status
      end
    end

    def stop
      begin
        Process.kill(:KILL, @child_pid)
      rescue Errno::ESRCH
        # NOTE: We can ignore this error because there process is already dead.
      end
      @service.stop_service
    end

    private

    def build_client
      Client.new(
        @service.uri,
        paths: @paths,
        recursive: @recursive,
        force_polling: @force_polling,
        poll_interval: @poll_interval,
        debounce: @debounce,
        ignore_remove: @ignore_remove
      )
    end
  end
end
