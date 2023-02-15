module Watchcat
  class Client
    def initialize(uri, path:, recursive:)
      @watcher = Watchcat::Watcher.new
      @server = DRbObject.new_with_uri(uri)
      @path = path
      @recursive = recursive
    end

    def run
      @watcher.watch(@path, recursive: @recursive) do |event|
        @server.execute(event)
      end
    end
  end
end
