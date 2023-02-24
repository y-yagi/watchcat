require "watchcat/kind"

module Watchcat
  class Event
    attr_reader :kind, :paths, :raw_kind

    def initialize(kinds, paths, raw_kind)
      @paths = paths
      @raw_kind = raw_kind
      build_kind(kinds)
    end

    private

    def build_kind(kinds)
      @kind = Watchcat::EventKind.new
      event_kind = kinds.shift
      @kind.public_send("#{event_kind}=", Object.const_get("Watchcat::#{event_kind.capitalize}Kind").new)
      send("build_#{event_kind}_kind", kinds)
    end

    def build_access_kind(kinds)
      @kind.access.kind = kinds.shift

      if @kind.access.open? || @kind.access.close?
        @kind.access.access_mode = Watchcat::AccessMode.new(kinds.shift)
      end
    end

    def build_create_kind(kinds)
      @kind.create.kind = kinds.shift
    end

    def build_modify_kind(kinds)
      @kind.modify.kind = kinds.shift

      if @kind.modify.data_change?
        @kind.modify.data_change = Watchcat::DataChange.new(kinds.shift)
      elsif @kind.modify.metadata?
        @kind.modify.metadata = Watchcat::MetadataKind.new(kinds.shift)
      elsif @kind.modify.rename?
        @kind.modify.rename = Watchcat::RenameMode.new(kinds.shift)
      end
    end

    def build_remove_kind(kinds)
      @kind.remove.kind = kinds.shift
    end
  end
end
