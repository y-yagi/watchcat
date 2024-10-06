# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class WatchcatTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("watchcat")
  end

  def teardown
    @watchcat.stop
    FileUtils.remove_entry_secure(@tmpdir)
  end

  def test_watch_directory_with_recursive
    events = []
    @watchcat = Watchcat.watch(@tmpdir, recursive: true) { |e| events << e }

#    sleep 5
    puts "debug :01"
    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "a.txt"))
    sleep 0.2
    FileUtils.touch(File.join(@tmpdir, "b.txt"))
    sleep 0.2
    sub_dir = FileUtils.mkdir(File.join(@tmpdir, "c"))
    sleep 0.2
    FileUtils.touch(File.join(sub_dir, "d.txt"))
    sleep 0.2

    puts "debug :02"
    if RUBY_PLATFORM.match?("linux")
      assert_equal 7, events.count
    else
      assert_equal 4, events.count
    end
  end
end
