# frozen_string_literal: true

require "rake/testtask"
require "rb_sys/extensiontask"
require "bundler/gem_tasks"
require "ruby_memcheck"

task default: :test

GEMSPEC = Gem::Specification.load("watchcat.gemspec")
RbSys::ExtensionTask.new("watchcat", GEMSPEC) do |ext|
  ext.lib_dir = "lib/watchcat"
end

test_config = lambda do |t|
  t.libs << "test"
  t.libs << "lib"
  t.deps << :compile
  t.test_files = FileList[File.expand_path("test/**/*_test.rb", __dir__)]
  t.warning = true
  t.verbose = true
end

Rake::TestTask.new(&test_config)
namespace :test do
  RubyMemcheck::TestTask.new(:valgrind, &test_config)
end

task console: :compile do
  ruby "bin/console"
end
