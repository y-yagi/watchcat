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
end
