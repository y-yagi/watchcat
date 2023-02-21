module Watchcat
  class Client
    def initialize(uri, paths:, recursive:, force_polling:)
      DRb.start_service
      @watcher = Watchcat::Watcher.new
      @server = DRbObject.new_with_uri(uri)
      @paths = paths
      @recursive = recursive
      @force_polling = force_polling
    end

    def run
      @watcher.watch(@paths, recursive: @recursive, force_polling: @force_polling) do |notification|
        @server.execute(notification)
      end
    end
  end
end
