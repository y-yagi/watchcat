# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class Watchcat::EventHandlerTest < Minitest::Test
  class RecordingHandler < Watchcat::EventHandler
    attr_reader :calls, :renamed_events

    def initialize
      @calls = []
      @renamed_events = []
    end

    def on_any_event(event)
      @calls << :on_any_event
    end

    def on_create(event)
      @calls << :on_create
    end

    def on_modify(event)
      @calls << :on_modify
    end

    def on_remove(event)
      @calls << :on_remove
    end

    def on_rename(event)
      @calls << :on_rename
      @renamed_events << event
    end

    def on_access(event)
      @calls << :on_access
    end
  end

  def setup
    @tmpdir = Dir.mktmpdir("watchcat")
    sleep 0.2
  end

  def teardown
    @watchcat.stop if @watchcat
    FileUtils.remove_entry_secure(@tmpdir)
  end

  def test_dispatch_routes_create_event
    handler = RecordingHandler.new
    event = Watchcat::Event.new(["create", "file"], [File.join(@tmpdir, "a.txt")], "create")

    handler.dispatch(event)

    assert_equal [:on_any_event, :on_create], handler.calls
  end

  def test_dispatch_routes_remove_event
    handler = RecordingHandler.new
    event = Watchcat::Event.new(["remove", "file"], [File.join(@tmpdir, "a.txt")], "remove")

    handler.dispatch(event)

    assert_equal [:on_any_event, :on_remove], handler.calls
  end

  def test_dispatch_routes_modify_event
    handler = RecordingHandler.new
    event = Watchcat::Event.new(["modify", "data_change", "content"], [File.join(@tmpdir, "a.txt")], "modify")

    handler.dispatch(event)

    assert_equal [:on_any_event, :on_modify], handler.calls
  end

  def test_dispatch_routes_rename_event_to_on_rename
    handler = RecordingHandler.new
    old_path = File.join(@tmpdir, "a.txt")
    new_path = File.join(@tmpdir, "b.txt")
    event = Watchcat::Event.new(["modify", "rename", "both"], [old_path, new_path], "modify")

    handler.dispatch(event)

    assert_equal [:on_any_event, :on_rename], handler.calls

    renamed_event = handler.renamed_events.first
    assert_equal old_path, renamed_event.src_path
    assert_equal new_path, renamed_event.dest_path
  end

  def test_dispatch_routes_access_event
    handler = RecordingHandler.new
    event = Watchcat::Event.new(["access", "open", "read"], [File.join(@tmpdir, "a.txt")], "access")

    handler.dispatch(event)

    assert_equal [:on_any_event, :on_access], handler.calls
  end

  def test_dispatch_routes_unknown_event_to_on_any_event_only
    handler = RecordingHandler.new
    event = Watchcat::Event.new([], [@tmpdir], "unknown")

    handler.dispatch(event)

    assert_equal [:on_any_event], handler.calls
  end

  def test_handler_receives_real_create_and_rename_events
    handler = RecordingHandler.new
    sleep 0.2
    @watchcat = Watchcat.watch(@tmpdir, recursive: false, handler: handler)
    sleep 0.2

    file = FileUtils.touch(File.join(@tmpdir, "a.txt"))[0]
    sleep 0.2

    assert_includes handler.calls, :on_create, handler.calls.inspect

    new_file = File.join(@tmpdir, "b.txt")
    File.rename(file, new_file)
    sleep 0.2

    assert_includes handler.calls, :on_rename, handler.calls.inspect
  end
end
