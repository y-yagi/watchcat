module Watchcat
  class Event
    attr_reader :kind, :paths

    def initialize(kind, paths)
      @kind = kind
      @paths = paths
    end
  end
end
