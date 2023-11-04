# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "watchcat"
require "debug"

require 'minitest/retry'
Minitest::Retry.use!(retry_count: 5)

require "minitest/autorun"
