module Watchcat
  class Server
    def initialize(args)
      @paths_with_block = args
    end

    def execute(event)
      event.paths.each do |path|
        @paths_with_block[path].call(event) if @paths_with_block.key?(path)
      end
    end
  end
end
