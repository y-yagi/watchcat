require "watchcat/event"

module Watchcat
  class Client
    def initialize(paths:, recursive:, force_polling:, poll_interval:, callback:)
      @watcher = Watchcat::Watcher.new
      @paths = paths
      @recursive = recursive
      @force_polling = force_polling
      @poll_interval = poll_interval
      @callback = callback
    end

    def run
      @watcher.watch(
        @paths,
        recursive: @recursive,
        force_polling: @force_polling,
        poll_interval: @poll_interval
      ) do |notification|
        event = Watchcat::Event.new(notification[0], notification[1], notification[2])
        @callback.call(event)
      end
    end
  end
end
