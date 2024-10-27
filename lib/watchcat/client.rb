module Watchcat
  class Client
    def initialize(uri, paths:, recursive:, force_polling:, poll_interval:, ignore_remove:)
      DRb.start_service
      @watcher = Watchcat::Watcher.new
      @server = DRbObject.new_with_uri(uri)
      @paths = paths
      @recursive = recursive
      @force_polling = force_polling
      @poll_interval = poll_interval
      @ignore_remove = ignore_remove
    end

    def run
      @watcher.watch(
        @paths,
        recursive: @recursive,
        force_polling: @force_polling,
        poll_interval: @poll_interval,
        ignore_remove: @ignore_remove
      ) { |notification| @server.execute(notification) }
    end
  end
end
