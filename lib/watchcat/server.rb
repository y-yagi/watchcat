module Watchcat
  class Server
    def initialize(block)
      @block = block
    end

    def execute(event)
      @block.call(event)
    end
  end
end
