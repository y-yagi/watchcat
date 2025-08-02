# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "watchcat"
require "debug"

if ENV["CI"]
  require 'minitest/retry'
  Minitest::Retry.use!
end

def inspect_events(events)
  events.map {|e| [e.paths, e.raw_kind] }
end

def mac_os?
  RUBY_PLATFORM.match?("darwin")
end

def windows?
  RUBY_PLATFORM.match?("mswin|mingw|cygwin")
end

require "minitest/autorun"
