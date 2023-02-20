module Watchcat
  class Client
    def initialize(uri, paths:, recursive:)
      DRb.start_service
      @watcher = Watchcat::Watcher.new
      @server = DRbObject.new_with_uri(uri)
      @paths = paths
      @recursive = recursive
    end

    def run
      @watcher.watch(@paths, recursive: @recursive) do |notification|
        @server.execute(notification)
      end
    end
  end
end
