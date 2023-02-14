require "drb"
require "drb/unix"
require_relative "server"

module Watchcat
  class Executor
    def initialize
      @service = nil
      @child_pid = nil
      @args_for_client = {}
      @args_for_server = {}
    end

    def add(path, recursive: false, &block)
      @args_for_client[path] = recursive
      @args_for_server[path] = block
    end

    def start
      server = Server.new(@args_for_server)
      @service = DRb.start_service("drbunix:", server)
      @child_pid = fork do
        client = Client.new(@service.uri, @args_for_client)
        client.run
      end
    end

    def stop
      Process.kill(:KILL, @child_pid)
      @service.stop_service
    end
  end
end
