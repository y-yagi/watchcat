require "watchcat/kind"

module Watchcat
  class Event
    attr_reader :kind, :paths, :raw_kind

    def initialize(kind, paths, raw_kind)
      @paths = paths
      @kind = {
        1 => Watchcat::AccessKind, 2 => Watchcat::CreateKind, 3 => Watchcat::ModifyKind,
        4 => Watchcat::RemoveKind, 5 => Watchcat::OtherKind
      }[kind]
      @raw_kind = raw_kind
    end
  end
end
