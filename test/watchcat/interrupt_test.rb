# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "timeout"

class Watchcat::InterruptTest < Minitest::Test
  class CustomError < StandardError; end

  def setup
    @tmpdir = Dir.mktmpdir("watchcat")
    @watcher = Watchcat::Watcher.new
    @thread = nil
    sleep 0.2
  end

  def teardown
    @watcher.close
    @thread&.kill
    @thread&.join(2) rescue nil
    FileUtils.remove_entry_secure(@tmpdir)
  end

  def start_watching(&block)
    block ||= proc { |_| }
    @thread = Thread.new do
      Thread.current.report_on_exception = false
      @watcher.watch([@tmpdir], recursive: true, &block)
    end
    sleep 0.3
    @thread
  end

  def test_thread_kill_terminates_watch
    start_watching
    @thread.kill

    assert @thread.join(2), "watcher thread did not terminate"
  end

  def test_thread_raise_propagates_exception
    start_watching
    @thread.raise(CustomError, "boom")

    error = assert_raises(CustomError) do
      assert @thread.join(2), "watcher thread did not terminate"
    end
    assert_equal "boom", error.message
  end

  def test_timeout_interrupts_watch
    runner = Thread.new do
      Thread.current.report_on_exception = false
      Timeout.timeout(0.5) { @watcher.watch([@tmpdir], recursive: true) { |_| } }
    rescue Timeout::Error => e
      e
    end
    @thread = runner

    assert runner.join(3), "Timeout did not interrupt watch"
    assert_kind_of Timeout::Error, runner.value
  end

  def test_thread_wakeup_keeps_watching
    events = Queue.new
    start_watching { |*args| events << args }

    @thread.wakeup
    @thread.run
    sleep 0.3
    assert @thread.alive?, "watcher thread stopped after wakeup"

    File.write(File.join(@tmpdir, "woken.txt"), "hello")
    Timeout.timeout(3) { events.pop }

    @watcher.close
    assert @thread.join(2), "watcher thread did not terminate after close"
  end

  def test_thread_kill_during_block_terminates_watch
    entered = Queue.new
    start_watching { |_| entered << true; sleep 5 }

    File.write(File.join(@tmpdir, "kill.txt"), "hello")
    Timeout.timeout(3) { entered.pop }
    @thread.kill

    assert @thread.join(2), "watcher thread did not terminate"
  end

  def test_thread_raise_during_block_propagates_exception
    entered = Queue.new
    start_watching { |_| entered << true; sleep 5 }

    File.write(File.join(@tmpdir, "raise.txt"), "hello")
    Timeout.timeout(3) { entered.pop }
    @thread.raise(CustomError, "boom")

    error = assert_raises(CustomError) do
      assert @thread.join(2), "watcher thread did not terminate"
    end
    assert_equal "boom", error.message
  end

  def test_block_exception_propagates_as_is
    start_watching { |_| raise CustomError, "from block" }

    File.write(File.join(@tmpdir, "block.txt"), "hello")

    error = assert_raises(CustomError) do
      assert @thread.join(3), "watcher thread did not terminate"
    end
    assert_equal "from block", error.message
  end
end
