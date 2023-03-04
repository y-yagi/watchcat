# frozen_string_literal: true

require "rake/testtask"
require "rb_sys/extensiontask"

task default: :test

GEMSPEC = Gem::Specification.load("watchcat.gemspec")
RbSys::ExtensionTask.new("watchcat", GEMSPEC) do |ext|
  ext.lib_dir = "lib/watchcat"
  ext.cross_compile = true
  ext.cross_platform = %w[x86_64-linux aarch64-linux x86_64-darwin arm64-darwin]
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.libs << "lib"
  t.deps << :compile
  t.test_files = FileList[File.expand_path("test/**/*_test.rb", __dir__)]
end

task console: :compile do
  ruby "bin/console"
end
