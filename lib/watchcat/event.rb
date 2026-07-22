require "watchcat/kind"

module Watchcat
  class Event
    attr_reader :kind, :paths, :raw_kind, :event

    def initialize(kinds, paths, raw_kind)
      @paths = paths
      @raw_kind = raw_kind
      build_kind(kinds)
    end

    def deconstruct_keys(_keys)
      { paths: @paths, event: @event }
    end

    def directory?
      if kind.create?
        kind.create.folder?
      elsif kind.remove?
        kind.remove.folder?
      elsif kind.any?
        kind.any.folder?
      else
        File.directory?(@paths.first)
      end
    rescue
      false
    end

    def src_path
      return nil unless rename_event?

      rename = kind.modify.rename
      return @paths[0] if rename.both? || rename.from?

      nil
    end

    def dest_path
      return nil unless rename_event?

      rename = kind.modify.rename
      return @paths[1] if rename.both?
      return @paths[0] if rename.to?

      nil
    end

    private

    def rename_event?
      kind.modify? && kind.modify.rename?
    end

    def build_kind(kinds)
      @kind = Watchcat::EventKind.new
      @event = kinds.shift
      if event
        @kind.public_send("#{event}=", Object.const_get("Watchcat::#{event.capitalize}Kind").new)
        send("build_#{event}_kind", kinds)
      else
        @kind.any = Watchcat::AnyKind.new
        if File.directory?(@paths.first)
          @kind.any.kind = "folder"
        else
          @kind.any.kind = "file"
        end
      end
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
