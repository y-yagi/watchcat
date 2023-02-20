# frozen_string_literal: true

require "rake/testtask"
require "rake/extensiontask"

task default: :test

Rake::ExtensionTask.new("watchcat") do |c|
  c.lib_dir = "lib/watchcat"
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.libs << "lib"
  t.deps << :compile
  t.test_files = FileList[File.expand_path("test/*_test.rb", __dir__)]
end

task console: :compile do
  ruby "bin/console"
end
