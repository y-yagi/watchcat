# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class Watchcat::KindTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("watchcat")
  end

  def teardown
    @watchcat.stop
    FileUtils.remove_entry_secure(@tmpdir)
  end

  def test_remove_file
    file = FileUtils.touch(File.join(@tmpdir, "a.txt"))

    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: false) { |e| events << e }
    sleep 0.1
    FileUtils.remove(file)
    sleep 0.1

    assert_equal 1, events.count
    event = events.first
    assert event.kind.remove?
    assert event.kind.remove.file?
    refute event.kind.remove.folder?
  end

  def test_remove_directory
    dir = File.join(@tmpdir, "dir")
    Dir.mkdir(dir)

    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: false) { |e| events << e }
    sleep 0.1
    FileUtils.remove_dir(dir)
    sleep 0.1

    assert_equal 1, events.count
    event = events.first
    assert event.kind.remove?
    refute event.kind.remove.file?
    assert event.kind.remove.folder?
  end

  def test_create_file
    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: false) { |e| events << e }
    sleep 0.1
    file = FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.1

    assert_equal 2, events.count
    event = events.first
    assert event.kind.create?
    assert event.kind.create.file?
    refute event.kind.create.folder?
  end

  def test_create_directory
    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: false) { |e| events << e }
    sleep 0.1
    dir = File.join(@tmpdir, "dir")
    Dir.mkdir(dir)
    sleep 0.1

    assert_equal 1, events.count
    event = events.first
    assert event.kind.create?
    refute event.kind.create.file?
    assert event.kind.create.folder?
  end

  def test_mv_file
    file = FileUtils.touch(File.join(@tmpdir, "a.txt"))[0]
    new_file = File.join(@tmpdir, "b.txt")

    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: false) { |e| events << e }
    sleep 0.1
    File.rename(file, new_file)
    sleep 0.1

    assert_equal 3, events.count
    assert events[0].kind.modify?
    assert events[0].kind.modify.from?
    assert_equal [file], events[0].paths
    assert events[1].kind.modify?
    assert events[1].kind.modify.to?
    assert_equal [new_file], events[1].paths
    assert events[2].kind.modify?
    assert events[2].kind.modify.both?
    assert_equal [file, new_file], events[2].paths
  end
end
