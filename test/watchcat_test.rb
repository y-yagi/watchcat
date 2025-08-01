# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class WatchcatTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("watchcat")
    sleep 0.2
  end

  def teardown
    @watchcat.stop if @watchcat
    FileUtils.remove_entry_secure(@tmpdir)
  end

  def test_watch_directory_without_recursive
    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: false, wait_until_startup: true) { |e| events << e }

    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.3
    FileUtils.touch(File.join(@tmpdir, "b.txt"))
    sleep 0.3
    sub_dir = FileUtils.mkdir(File.join(@tmpdir, "c"))
    sleep 0.3
    FileUtils.touch(File.join(sub_dir, "d.txt"))
    sleep 0.3

    if RUBY_PLATFORM.match?("linux")
      assert_equal 7, events.count, inspect_events(events)
    else
      refute_equal 0, events.count, inspect_events(events)
    end

    events.each do |event|
      event.paths.each { |path| refute_equal "d.txt", File.basename(path) }
    end
  end

  def test_watch_directory_with_recursive
    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: true, wait_until_startup: true) { |e| events << e }

    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "b.txt"))
    sleep 0.2
    sub_dir = FileUtils.mkdir(File.join(@tmpdir, "c"))
    sleep 0.2
    FileUtils.touch(File.join(sub_dir, "d.txt"))
    sleep 0.2

    if RUBY_PLATFORM.match?("linux")
      assert_equal 11, events.count, inspect_events(events)
    else
      assert_equal 4, events.count, inspect_events(events)
    end
  end

  def test_watch_directory_with_recursive_and_debonuce
    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: true, debounce: 200, wait_until_startup: true) { |e| events << e }

    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    FileUtils.touch(File.join(@tmpdir, "b.txt"))
    sub_dir = FileUtils.mkdir(File.join(@tmpdir, "c"))
    FileUtils.touch(File.join(sub_dir, "d.txt"))
    sleep 1

    assert_equal 4, events.count, inspect_events(events)
  end


  def test_watch_file
    skip unless RUBY_PLATFORM.match?("linux")

    file = FileUtils.touch(File.join(@tmpdir, "a.txt"))
    events = []
    @watchcat = Watchcat.watch(file) { |e| events << e }

    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "b.txt"))

    sleep 0.2
    assert_equal 1, events.count, inspect_events(events)
  end

  def test_watch_directory_with_force_polling
    skip unless RUBY_PLATFORM.match?("linux")

    events = []
    @watchcat = Watchcat.watch(@tmpdir, force_polling: true) { |e| events << e }
    pid = Process.pid
    sleep 0.2
    inotify_count = `cat /proc/#{pid}/fdinfo/* | grep inotify | wc -l`.to_i

    assert_equal 0, inotify_count

    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.5
    refute_equal 0, events.count
  end

  def test_watch_directory_with_poll_interval
    skip unless RUBY_PLATFORM.match?("linux")

    events = []
    @watchcat =
      Watchcat.watch(@tmpdir, force_polling: true, poll_interval: 1000) do |e|
        events << e
      end
    pid = Process.pid
    sleep 0.2
    inotify_count = `cat /proc/#{pid}/fdinfo/* | grep inotify | wc -l`.to_i

    assert_equal 0, inotify_count

    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.2
    assert_equal 0, events.count
    sleep 1
    refute_equal 0, events.count
  end

  def test_match_event
    skip unless RUBY_PLATFORM.match?("linux")

    events = []
    @watchcat = Watchcat.watch(@tmpdir) do |e|
      case e
      in event: "create", paths: ["#{File.join(@tmpdir, "a.txt")}"]
        events << e
      else
        # Do nothing.
      end
    end

    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "b.txt"))

    sleep 0.2
    assert_equal 1, events.count, inspect_events(events)
  end

  def test_watch_with_ignore_remove
    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: true, wait_until_startup: true, ignore_remove: true) { |e| events << e }

    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "b.txt"))
    sleep 0.2
    sub_dir = FileUtils.mkdir(File.join(@tmpdir, "c"))[0]
    sleep 0.2
    FileUtils.touch(File.join(sub_dir, "d.txt"))
    sleep 0.2
    FileUtils.remove_file(File.join(sub_dir, "d.txt"))
    sleep 0.2
    FileUtils.remove_dir(sub_dir)
    sleep 0.2

    if RUBY_PLATFORM.match?("linux")
      assert_equal 13, events.count, inspect_events(events)
    else
      assert_equal 6, events.count, inspect_events(events)
    end
  end

  def test_watch_with_ignore_remove_and_debounce
    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: true, debounce: 200, wait_until_startup: true, ignore_remove: true) { |e| events << e }

    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    FileUtils.touch(File.join(@tmpdir, "b.txt"))
    sub_dir = FileUtils.mkdir(File.join(@tmpdir, "c"))[0]
    FileUtils.touch(File.join(sub_dir, "d.txt"))
    FileUtils.remove_file(File.join(sub_dir, "d.txt"))
    FileUtils.remove_dir(sub_dir)
    sleep 1.0

    assert_equal 2, events.count, inspect_events(events)
  end
end
