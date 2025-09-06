require "optparse"
require_relative "cli/watcher"
require_relative "cli/config"
require_relative "cli/action_executor"

module Watchcat
  module CLI
    class Error < StandardError; end
    class << self
      def start(argv)
        options = parse(argv)

        if options[:init]
          Config.generate_template(options[:init])
          return
        end

        config = Config.load(options[:config])
        watcher = Watcher.new(config)
        watcher.start
      rescue => e
        raise Error, "Failed to start Watchcat: #{e.message}"
      end

      def parse(argv)
        options = {}
        OptionParser.new do |opts|
          opts.banner = "Usage: watchcat [options]"

          opts.on("-C", "--config PATH", "Path to the config file") do |v|
            options[:config] = v
          end

          opts.on("--init PATH", "Generate a template config file at the specified path") do |v|
            options[:init] = v
          end

          opts.on("-h", "--help", "Show this help message") do
            puts opts
            exit
          end
        end.parse!(argv)

        if !options[:init] && options[:config].nil?
          raise OptionParser::MissingArgument.new("-C")
        end

        options
      end
    end
  end
end
