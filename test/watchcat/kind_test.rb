# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class Watchcat::KindTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("watchcat")
  end

  def teardown
    FileUtils.remove_entry_secure(@tmpdir)
  end

  def test_remove_file
    file = FileUtils.touch(File.join(@tmpdir, "a.txt"))

    events = []
    sleep 0.2
    @watchcat = Watchcat.watch(@tmpdir, recursive: false, wait_until_startup: true) { |e| events << e }
    sleep 0.2
    FileUtils.remove(file)
    sleep 0.2

    if RUBY_PLATFORM.match?("linux")
      assert_equal 1, events.count, inspect_events(events)
    else
      assert_equal 2, events.count, inspect_events(events)
    end

    event = events.last
    assert event.kind.remove?
    assert event.kind.remove.file?
    refute event.kind.remove.folder?
  end

  def test_remove_directory
    dir = File.join(@tmpdir, "dir")
    Dir.mkdir(dir)

    events = []
    sleep 0.2
    @watchcat = Watchcat.watch(@tmpdir, recursive: false, wait_until_startup: true) { |e| events << e }
    sleep 0.2
    FileUtils.remove_dir(dir)
    sleep 0.2

    if RUBY_PLATFORM.match?("linux")
      assert_equal 2, events.count, inspect_events(events)
    else
      assert_equal 2, events.count, inspect_events(events)
    end
    event = events.last
    assert event.kind.remove?
    refute event.kind.remove.file?
    assert event.kind.remove.folder?
  end

  def test_create_file
    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: false, wait_until_startup: true) { |e| events << e }
    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.2

    if RUBY_PLATFORM.match?("linux")
      assert_equal 3, events.count, inspect_events(events)
    else
      assert_equal 1, events.count, inspect_events(events)
    end
    event = events.first
    assert event.kind.create?
    assert event.kind.create.file?
    refute event.kind.create.folder?
  end

  def test_create_file_with_debonuce
    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: false, debounce: 100, wait_until_startup: true) { |e| events << e }
    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.4

    assert_equal 1, events.count, inspect_events(events)
    event = events.first
    assert event.kind.any?
    assert event.kind.any.file?
    refute event.kind.any.folder?
  end

  def test_create_directory
    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: false, wait_until_startup: true) { |e| events << e }
    sleep 0.2
    dir = File.join(@tmpdir, "dir")
    Dir.mkdir(dir)
    sleep 0.2

    assert_equal 1, events.count, inspect_events(events)
    event = events.first
    assert event.kind.create?
    refute event.kind.create.file?
    assert event.kind.create.folder?
  end

  def test_create_directory_with_debounce
    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: false, debounce: 100, wait_until_startup: true) { |e| events << e }
    sleep 0.2
    dir = File.join(@tmpdir, "dir")
    Dir.mkdir(dir)
    sleep 0.4

    assert_equal 1, events.count, inspect_events(events)
    event = events.first
    assert event.kind.any?
    refute event.kind.any.file?
    assert event.kind.any.folder?
  end

  def test_mv_file
    file = FileUtils.touch(File.join(@tmpdir, "a.txt"))[0]
    new_file = File.join(@tmpdir, "b.txt")

    events = []
    sleep 0.2
    @watchcat = Watchcat.watch(@tmpdir, recursive: false, wait_until_startup: true) { |e| events << e }
    sleep 0.2
    File.rename(file, new_file)
    sleep 0.2

    assert_equal 3, events.count, inspect_events(events)
    if RUBY_PLATFORM.match?("linux")
      assert events[0].kind.modify?
      assert events[0].kind.modify.from?
      assert_equal [file], events[0].paths
      assert events[1].kind.modify?
      assert events[1].kind.modify.to?
      assert_equal [new_file], events[1].paths
      assert events[2].kind.modify?
      assert events[2].kind.modify.both?
      assert_equal [file, new_file], events[2].paths
    else
      assert events[0].kind.create?
      assert events[0].kind.create.file?
      assert_equal File.basename(file), File.basename(events[0].paths[0])
      assert events[1].kind.modify?
      assert events[1].kind.modify.rename?
      assert_equal File.basename(file), File.basename(events[1].paths[0])
      assert events[2].kind.modify?
      assert events[2].kind.modify.rename?
      assert_equal File.basename(new_file), File.basename(events[2].paths[0])
    end
  end

  def test_write_to_file
    file = FileUtils.touch(File.join(@tmpdir, "a.txt"))[0]

    events = []
    sleep 0.2
    @watchcat = Watchcat.watch(@tmpdir, recursive: false, wait_until_startup: true) { |e| events << e }
    sleep 0.2
    system("echo 'a' >> #{file}", exception: true)
    sleep 0.2

    if RUBY_PLATFORM.match?("linux")
      assert_equal 3, events.count, inspect_events(events)
      assert events[0].kind.access?
      assert events[0].kind.access.open?
      refute events[0].kind.access.write_mode?
      assert events[1].kind.modify?
      assert events[1].kind.modify.data_change?
      assert events[2].kind.access?
      assert events[2].kind.access.close?
      assert events[2].kind.access.write_mode?
    else
      assert_equal 2, events.count, inspect_events(events)
      assert events[0].kind.create?
      assert events[0].kind.create.file?
      assert events[1].kind.modify?
      assert events[1].kind.modify.data_change?
      assert events[1].kind.modify.data_change.content?
    end
  end

  def test_chmod_file
    file = FileUtils.touch(File.join(@tmpdir, "a.txt"))[0]

    events = []
    sleep 0.2
    @watchcat = Watchcat.watch(@tmpdir, recursive: false, wait_until_startup: true) { |e| events << e }
    sleep 0.2
    FileUtils.chmod(0644, file)
    sleep 0.2

    if RUBY_PLATFORM.match?("linux")
      assert_equal 1, events.count, inspect_events(events)
    else
      assert_equal 2, events.count, inspect_events(events)
    end

    event = events.last
    assert event.kind.modify?
    assert event.kind.modify.metadata?
    assert event.kind.modify.ownership? unless RUBY_PLATFORM.match?("linux")
  end
end
