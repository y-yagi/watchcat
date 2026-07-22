# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class Watchcat::DynamicPathsTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("watchcat")
    @tmpdir2 = Dir.mktmpdir("watchcat")
    sleep 0.2
  end

  def teardown
    @watchcat&.stop
    FileUtils.remove_entry_secure(@tmpdir)
    FileUtils.remove_entry_secure(@tmpdir2)
  end

  def test_watch_nonexistent_path_raises
    @watchcat = Watchcat.watch(@tmpdir, recursive: false) { |e| }
    sleep 0.2

    assert_raises(ArgumentError) { @watchcat.watch("/no/such/path/xyz") }
  end

  def test_watched_reflects_watch_and_unwatch
    @watchcat = Watchcat.watch(@tmpdir, recursive: false) { |e| }
    sleep 0.2

    @watchcat.watch(@tmpdir2)
    assert_includes @watchcat.watched, @tmpdir
    assert_includes @watchcat.watched, @tmpdir2

    @watchcat.unwatch(@tmpdir)
    refute_includes @watchcat.watched, @tmpdir
    assert_includes @watchcat.watched, @tmpdir2
  end

  def test_watch_watches_new_directory
    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: false) { |e| events << e }
    sleep 0.2

    @watchcat.watch(@tmpdir2, recursive: false)
    sleep 0.2

    FileUtils.touch(File.join(@tmpdir2, "a.txt"))
    sleep 0.3

    assert events.any? { |e| e.paths.any? { |p| p.to_s.include?(@tmpdir2) } }, inspect_events(events)
  end

  def test_unwatch_stops_events
    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: false) { |e| events << e }
    sleep 0.2

    @watchcat.watch(@tmpdir2, recursive: false)
    sleep 0.2

    @watchcat.unwatch(@tmpdir)
    sleep 0.3

    events.clear

    FileUtils.touch(File.join(@tmpdir2, "b.txt"))
    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.3

    assert events.any? { |e| e.paths.any? { |p| p.to_s.include?(@tmpdir2) } }, inspect_events(events)

    unless mac_os?
      refute events.any? { |e| e.paths.any? { |p| p.to_s.include?(@tmpdir) && !p.to_s.include?(@tmpdir2) } },
             inspect_events(events)
    end
  end
end
