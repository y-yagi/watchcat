module Watchcat
  class Client
    def initialize(uri, watcher:, paths:, recursive:, force_polling:, poll_interval:, ignore_remove:, debounce:)
      DRb.start_service
      @watcher = watcher
      @server = DRbObject.new_with_uri(uri)
      @paths = paths
      @recursive = recursive
      @force_polling = force_polling
      @poll_interval = poll_interval
      @ignore_remove = ignore_remove
      @debounce = debounce
    end

    def run
      @watcher.watch(
        @paths,
        recursive: @recursive,
        force_polling: @force_polling,
        poll_interval: @poll_interval,
        ignore_remove: @ignore_remove,
        debounce: @debounce
      ) { |notification| @server.execute(notification) }
    end
  end
end
