require "psych"

module Watchcat
  module CLI
    class Config
      attr_reader :watches

      def initialize(data)
        @watches = parse_watches(data["watches"] || [])
      end

      def self.load(file_path)
        unless File.exist?(file_path)
          raise Error, "Configuration file not found: #{file_path}"
        end

        begin
          data = Psych.load_file(file_path)
          new(data)
        rescue Psych::SyntaxError => e
          raise Error, "Invalid YAML syntax in #{file_path}: #{e.message}"
        end
      end

      def self.generate_template(file_path)
        template = <<~YAML
          # Watchcat Configuration File

          watches:
            - path: "./src"
              recursive: true
              debounce: 300
              filters:
                ignore_access: true
              patterns:
                - "*.js"
                - "*.ts"
                - "*.css"
              actions:
                - command: "echo 'File changed: {{file_path}}'"

            - path: "./docs"
              recursive: true
              filters:
                ignore_access: true
              patterns:
                - "*.md"
              actions:
                - command: "echo 'Documentation updated: {{file_name}}'"
        YAML

        if File.exist?(file_path)
          raise Error, "File already exists: #{file_path}. Won't overwrite."
        end

        File.write(file_path, template)
        puts "Config template generated at #{file_path}"
      end

      private

      def parse_watches(watches_data)
        watches_data.map do |watch_config|
          {
            path: watch_config["path"],
            recursive: watch_config.fetch("recursive", true),
            patterns: watch_config["patterns"] || [],
            actions: watch_config["actions"] || [],
            debounce: watch_config.fetch("debounce", -1),
            filters: watch_config["filters"]&.transform_keys(&:to_sym) || {},
          }
        end
      end
    end
  end
end
