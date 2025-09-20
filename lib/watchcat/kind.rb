require "forwardable"

module Watchcat
  class EventKind
    attr_accessor :access, :create, :modify, :remove, :any

    def initialize
      @access, @create, @modify, @remove, @any = nil, nil, nil, nil,nil
    end

    def access?
      !@access.nil?
    end

    def create?
      !@create.nil?
    end

    def modify?
      !@modify.nil?
    end

    def remove?
      !@remove.nil?
    end

    def any?
      !@any.nil?
    end

    def event_type
      return "create" if create?
      return "modify" if modify?
      return "remove" if remove?
      return "access" if access?
      "unknown"
    end
  end

  class AccessKind
    extend Forwardable

    attr_accessor :kind, :access_mode
    delegate [:excute_mode?, :read_mode?, :write_mode?] => :@access_mode

    def initialize
      @kind, @access_mode = nil, nil
    end

    def read?
      @kind == "read"
    end

    def open?
      @kind == "open"
    end

    def close?
      @kind == "close"
    end
  end

  class CreateKind
    attr_accessor :kind

    def file?
      @kind == "file"
    end

    def folder?
      @kind == "folder"
    end
  end

  class ModifyKind
    extend Forwardable

    attr_accessor :kind, :data_change, :metadata, :rename
    delegate [:size?, :content?] => :@data_change
    delegate [:access_time?, :write_time?, :permission?, :ownership?, :extended?] => :@metadata
    delegate [:from?, :to?, :both?] => :@rename

    def initialize
      @kind, @data_change, @metadata, @rename = nil, nil, nil, nil
    end

    def data_change?
      @kind == "data_change"
    end

    def metadata?
      @kind == "metadata"
    end

    def rename?
      @kind == "rename"
    end
  end

  class RemoveKind
    attr_accessor :kind

    def file?
      @kind == "file"
    end

    def folder?
      @kind == "folder"
    end
  end

  class AnyKind
    attr_accessor :kind

    def file?
      @kind == "file"
    end

    def folder?
      @kind == "folder"
    end
  end


  class AccessMode
    attr_accessor :mode

    def initialize(mode)
      @mode = mode
    end

    def execute_mode?
      @mode == "execute"
    end

    def read_mode?
      @mode == "read"
    end

    def write_mode?
      @mode == "write"
    end
  end

  class DataChange
    attr_accessor :kind

    def initialize(kind)
      @kind = kind
    end

    def size?
      @kind == "size"
    end

    def content?
      @kind == "content"
    end
  end

  class MetadataKind
    attr_accessor :kind

    def initialize(kind)
      @kind = kind
    end

    def access_time?
      @kind == "access_time"
    end

    def write_time?
      @kind == "write_time"
    end

    def permission?
      @kind == "permission"
    end

    def ownership?
      @kind == "ownership"
    end

    def extended?
      @kind == "extended"
    end
  end

  class RenameMode
    attr_accessor :mode

    def initialize(mode)
      @mode = mode
    end

    def from?
      @mode == "from"
    end

    def to?
      @mode == "to"
    end

    def both?
      @mode == "both"
    end
  end
end
