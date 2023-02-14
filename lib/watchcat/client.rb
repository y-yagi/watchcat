module Watchcat
  class Client
    def initialize(uri, paths_with_option)
      @paths_with_option = paths_with_option
      @watcher = Watchcat::Watcher.new
      @server = DRbObject.new_with_uri(uri)
    end

    def run
      # TODO: pass all option
      option = @paths_with_option.first
      @watcher.watch(option[0], recursive: option[1]) do |event|
        @server.execute(event)
      end
    end
  end
end
