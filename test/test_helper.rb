# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "watchcat"
require "debug"

if ENV["CI"]
  require 'minitest/retry'
  Minitest::Retry.use!
end

require "minitest/autorun"
