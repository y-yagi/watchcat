# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class WatchcatTest < Minitest::Test
  def test_watch_directory_without_recursive
    @tmpdir = Dir.mktmpdir("watchcat")
    events = []
    w = Watchcat.watch(@tmpdir, recursive: false) { |e| events << e }

    sleep 0.1
    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.1
    FileUtils.touch(File.join(@tmpdir, "b.txt"))
    sleep 0.1
    sub_dir = FileUtils.mkdir(File.join(@tmpdir, "c"))
    sleep 0.1
    FileUtils.touch(File.join(sub_dir, "d.txt"))

    sleep 0.1
    assert_equal 5, events.count
  ensure
    w.stop
    FileUtils.remove_entry_secure(@tmpdir)
  end

  def test_watch_directory_with_recursive
    @tmpdir = Dir.mktmpdir("watchcat")
    events = []
    w = Watchcat.watch(@tmpdir, recursive: true) { |e| events << e }

    sleep 0.1
    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.1
    FileUtils.touch(File.join(@tmpdir, "b.txt"))
    sleep 0.1
    sub_dir = FileUtils.mkdir(File.join(@tmpdir, "c"))
    sleep 0.1
    FileUtils.touch(File.join(sub_dir, "d.txt"))

    sleep 0.1
    assert_equal 7, events.count
  ensure
    w.stop
    FileUtils.remove_entry_secure(@tmpdir)
  end

  def test_watch_file
    @tmpdir = Dir.mktmpdir("watchcat")
    file = FileUtils.touch(File.join(@tmpdir, "a.txt"))
    events = []
    w = Watchcat.watch(file) { |e| events << e }

    sleep 0.1
    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.1
    FileUtils.touch(File.join(@tmpdir, "b.txt"))

    sleep 0.1
    assert_equal 1, events.count
  ensure
    w.stop
    FileUtils.remove_entry_secure(@tmpdir)
  end

  def test_watch_directory_with_force_polling
    @tmpdir = Dir.mktmpdir("watchcat")
    events = []
    w = Watchcat.watch(@tmpdir, force_polling: true) { |e| events << e }
    pid = w.instance_variable_get(:@child_pid)
    sleep 0.1
    inotify_count = `cat /proc/#{pid}/fdinfo/* | grep inotify | wc -l`.to_i

    assert_equal 0, inotify_count

    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.3
    assert_equal 1, events.count
  ensure
    w.stop
    FileUtils.remove_entry_secure(@tmpdir)
  end
end
