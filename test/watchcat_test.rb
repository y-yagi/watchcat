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
    @watchcat = Watchcat.watch(@tmpdir, recursive: false) { |e| events << e }

    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.3
    FileUtils.touch(File.join(@tmpdir, "b.txt"))
    sleep 0.3
    sub_dir = FileUtils.mkdir(File.join(@tmpdir, "c"))
    sleep 0.3
    FileUtils.touch(File.join(sub_dir, "d.txt"))
    sleep 0.3

    if mac_os?
      refute_equal 0, events.count, inspect_events(events)
    elsif windows?
      assert_equal 3, events.count, inspect_events(events)
    else
      assert_equal 7, events.count, inspect_events(events)
    end

    events.each do |event|
      event.paths.each { |path| refute_equal "d.txt", File.basename(path) }
    end
  end

  def test_watch_directory_with_recursive
    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: true) { |e| events << e }

    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "b.txt"))
    sleep 0.2
    sub_dir = FileUtils.mkdir(File.join(@tmpdir, "c"))
    sleep 0.2
    FileUtils.touch(File.join(sub_dir, "d.txt"))
    sleep 0.2

    if mac_os? || windows?
      assert_equal 4, events.count, inspect_events(events)
    else
      assert_equal 11, events.count, inspect_events(events)
    end
  end

  def test_watch_directory_with_recursive_and_debonuce
    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: true, debounce: 200) { |e| events << e }

    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sub_dir = FileUtils.mkdir(File.join(@tmpdir, "c"))
    FileUtils.touch(File.join(sub_dir, "d.txt"))

    sleep 1
    events.clear
    3.times { FileUtils.touch(File.join(@tmpdir, "a.txt")) }
    3.times { FileUtils.touch(File.join(sub_dir, "d.txt")) }
    sleep 1

    assert_equal 2, events.count, inspect_events(events)
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
    skip if mac_os? || windows?

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
    @watchcat = Watchcat.watch(@tmpdir, recursive: true, filters: {ignore_remove: true}) { |e| events << e }

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

    if mac_os?
      assert_equal 6, events.count, inspect_events(events)
    elsif windows?
      assert_equal 5, events.count, inspect_events(events)
    else
      assert_equal 13, events.count, inspect_events(events)
    end
  end

  def test_watch_with_ignore_access
    events = []
    @watchcat = Watchcat.watch(
      @tmpdir,
      recursive: true,
      filters: {ignore_access: true}
    ) { |e| events << e }

    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.2
    File.open(File.join(@tmpdir, "a.txt"), "r") { |f| f.read }
    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "b.txt"))
    sleep 0.2

    # No access events should be present
    events.each do |event|
      refute event.kind.access?, "Access event was not filtered: #{event.kind.inspect}"
    end
  end

  def test_watch_with_ignore_create
    events = []
    @watchcat = Watchcat.watch(
      @tmpdir,
      recursive: true,
      filters: {ignore_create: true}
    ) { |e| events << e }

    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "b.txt"))
    sleep 0.2

    # No create events should be present
    events.each do |event|
      refute event.kind.create?, "Create event was not filtered: #{event.kind.inspect}"
    end
  end

  def test_watch_with_ignore_modify
    events = []
    @watchcat = Watchcat.watch(
      @tmpdir,
      recursive: true,
      filters: {ignore_modify: true}
    ) { |e| events << e }

    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "b.txt"))
    sleep 0.2
    File.open(File.join(@tmpdir, "a.txt"), "w") { |f| f.puts "update" }
    sleep 0.2

    # No modify events should be present
    events.each do |event|
      refute event.kind.modify?, "Modify event was not filtered: #{event.kind.inspect}"
    end
  end

  def test_watch_symlink_file
    skip if windows?

    target_file = File.join(@tmpdir, "target.txt")
    FileUtils.touch(target_file)

    symlink_file = File.join(@tmpdir, "link_to_file.txt")
    File.symlink(target_file, symlink_file)

    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: true) { |e| events << e }

    sleep 0.2
    # Modify the target file through the symlink
    File.open(symlink_file, "w") { |f| f.puts "modified via symlink" }
    sleep 0.3

    # Should detect events on both the symlink and potentially the target
    refute_equal 0, events.count, inspect_events(events)

    # At least one event should involve the symlink path
    symlink_events = events.select do |event|
      event.paths.any? { |path| path.include?("target.txt") }
    end
    refute_empty symlink_events, "No events detected for symlink file"
  end

  def test_watch_symlink_directory
    skip if windows?

    target_dir = File.join(@tmpdir, "target_dir")
    FileUtils.mkdir(target_dir)
    target_file = File.join(target_dir, "file.txt")
    FileUtils.touch(target_file)

    symlink_dir = File.join(@tmpdir, "link_to_dir")
    File.symlink(target_dir, symlink_dir)

    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: true) { |e| events << e }

    sleep 0.2
    # Create a new file in the target directory through the symlink
    new_file = File.join(symlink_dir, "new_file.txt")
    FileUtils.touch(new_file)
    sleep 0.3

    refute_equal 0, events.count, inspect_events(events)

    # Should detect events related to the symlinked directory
    symlink_events = events.select do |event|
      event.paths.any? { |path| path.include?("link_to_dir") || path.include?("new_file.txt") }
    end
    refute_empty symlink_events, "No events detected for symlinked directory operations"
  end

  def test_watch_broken_symlink
    skip if windows?

    # Create a symlink to a non-existent file
    broken_symlink = File.join(@tmpdir, "broken_link.txt")
    File.symlink("/non/existent/path", broken_symlink)

    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: true) { |e| events << e }

    sleep 0.2
    FileUtils.rm(broken_symlink)
    sleep 0.3

    refute_equal 0, events.count, inspect_events(events)

    broken_link_events = events.select do |event|
      event.paths.any? { |path| path.include?("broken_link.txt") }
    end
    refute_empty broken_link_events, "No events detected for broken symlink"
  end

  def test_watch_symlink_creation_and_deletion
    skip if windows?

    target_file = File.join(@tmpdir, "target.txt")
    FileUtils.touch(target_file)

    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: true) { |e| events << e }

    sleep 0.2
    events.clear # Clear any initial events

    symlink_file = File.join(@tmpdir, "dynamic_link.txt")
    File.symlink(target_file, symlink_file)
    sleep 0.3

    FileUtils.rm(symlink_file)
    sleep 0.3

    refute_equal 0, events.count, inspect_events(events)

    # Should have events for both creation and deletion
    create_events = events.select { |e| e.kind.create? }
    remove_events = events.select { |e| e.kind.remove? }

    if mac_os?
      # macOS might handle symlink events differently
      refute_equal 0, events.count, "Expected some events on macOS"
    else
      refute_empty create_events, "No create events detected for symlink"
      refute_empty remove_events, "No remove events detected for symlink"
    end
  end

  def test_watch_symlink_target_modification
    skip if windows?

    target_file = File.join(@tmpdir, "target.txt")
    FileUtils.touch(target_file)

    symlink_file = File.join(@tmpdir, "link.txt")
    File.symlink(target_file, symlink_file)

    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: true) { |e| events << e }

    sleep 0.2
    events.clear # Clear any initial events

    # Modify the target file directly (not through symlink)
    File.open(target_file, "w") { |f| f.puts "modified directly" }
    sleep 0.3

    refute_equal 0, events.count, inspect_events(events)

    # Should detect modification of the target file
    target_events = events.select do |event|
      event.paths.any? { |path| path.include?("target.txt") }
    end
    refute_empty target_events, "No events detected for target file modification"
  end
end
