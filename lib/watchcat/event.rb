require "watchcat/kind"

module Watchcat
  class Event
    attr_reader :kind, :paths, :raw_kind

    def initialize(kinds, paths, raw_kind)
      @paths = paths
      @kind = {
        "access" => Watchcat::AccessKind, "create" => Watchcat::CreateKind, "modify" => Watchcat::ModifyKind,
        "remove" => Watchcat::RemoveKind, "other" => Watchcat::OtherKind
      }[kinds[0]]
      @raw_kind = raw_kind
    end
  end
end
