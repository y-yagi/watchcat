require_relative "cli/watcher"
require_relative "cli/config"
require_relative "cli/action_executor"
require_relative "cli/debouncer"

module Watchcat
  module CLI
    class Error < StandardError; end

    class << self
      def start(config_file)
        config_file ||= "watchcat.yml"
        config = Config.load(config_file)
        watcher = Watcher.new(config)
        watcher.start
      rescue => e
        raise Error, "Failed to start Watchcat: #{e.message}"
      end
    end
  end
end
