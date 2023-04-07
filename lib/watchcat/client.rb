module Watchcat
  class Client
    def initialize(uri, paths:, recursive:, force_polling:, poll_interval:)
      DRb.start_service
      @watcher = Watchcat::Watcher.new
      @server = DRbObject.new_with_uri(uri)
      @paths = paths
      @recursive = recursive
      @force_polling = force_polling
      @poll_interval = poll_interval
    end

    def run
      @watcher.watch(
        @paths,
        recursive: @recursive,
        force_polling: @force_polling,
        poll_interval: @poll_interval
      ) { |notification| @server.execute(notification) }
    end
  end
end
