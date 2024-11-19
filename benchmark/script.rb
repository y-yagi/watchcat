#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "watchcat"
require "listen"
require "tmpdir"
require "fileutils"
require "time"

dir = Dir.mktmpdir("watchcat")

file_count = 10
if !ARGV.empty? && ARGV.first.start_with?("--file-count=")
  file_count = ARGV.first.split("--file-count=").last.to_i
end

file_count.times do |i|
  FileUtils.touch("#{dir}/#{i}.txt")
end

w = Watchcat.watch(dir) do |e|
  pp "#{Time.now} by Watchcat"
  pp e.paths
end


listener = Listen.to(dir) do |modified|
  pp "#{Time.now} by Listen"
  pp modified
end
listener.start

puts "start watching"
puts "-------------------------------------\n\n"

FileUtils.touch("#{dir}/0.txt")
puts "-------------------------------------\n\n"

sleep 1

FileUtils.touch("#{dir}/#{file_count-1}.txt")
puts "-------------------------------------\n\n"

at_exit do
  FileUtils.rm_rf(dir, verbose: true)
end
sleep
