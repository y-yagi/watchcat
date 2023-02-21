module Watchcat
  class Event
    attr_reader :kind, :paths, :raw_kind

    def initialize(kind, paths, raw_kind)
      @paths = paths
      @kind = { 1 => :access, 2 => :create, 3 => :modify, 4 => :remove, 5 => :other, 99 => :any }[kind]
      @raw_kind = raw_kind
    end
  end
end
