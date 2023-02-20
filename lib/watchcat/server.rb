require "watchcat/event"

module Watchcat
  class Server
    def initialize(block)
      @block = block
    end

    def execute(notification)
      event = Watchcat::Event.new(notification[0], notification[1])
      @block.call(event)
    end
  end
end
