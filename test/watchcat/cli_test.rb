# frozen_string_literal: true

require "test_helper"
require "watchcat/cli"
require "tmpdir"
require "fileutils"

class Watchcat::CLITest < Minitest::Test
  def test_config_loading
    Dir.mktmpdir do |tmpdir|
      config_file = File.join(tmpdir, "test_config.yml")

      config_content = <<~YAML
        watches:
          - path: "#{tmpdir}"
            recursive: true
            debounce: 1000
            patterns:
              - "*.txt"
            actions:
              - command: "echo 'Test file changed: {{file_name}}'"
      YAML

      File.write(config_file, config_content)

      config = Watchcat::CLI::Config.load(config_file)
      assert_equal 1, config.watches.length
      assert_equal tmpdir, config.watches.first[:path]
      assert_equal true, config.watches.first[:recursive]
      assert_equal 1000, config.watches.first[:debounce]
      assert_equal ["*.txt"], config.watches.first[:patterns]
      assert_equal 1, config.watches.first[:actions].length
      assert config.watches.first[:actions].first.has_key?("command")
    end
  end

  def test_action_executor_variable_substitution
    Dir.mktmpdir do |tmpdir|
      test_file = File.join(tmpdir, "test.rb")
      File.write(test_file, "# test file")

      # Mock event
      event = Object.new
      def event.kind
        mock_kind = Object.new
        def mock_kind.modify?; true; end
        def mock_kind.create?; false; end
        def mock_kind.remove?; false; end
        def mock_kind.access?; false; end
        mock_kind
      end

      executor = Watchcat::CLI::ActionExecutor.new(test_file, event)

      # Test variable substitution
      template = "File: {{file_name}}, Dir: {{file_dir}}"
      result = executor.send(:substitute_variables, template)

      assert_includes result, "test.rb"
      assert_includes result, tmpdir
    end
  end

  def test_config_missing_file
    assert_raises(Watchcat::CLI::Error) do
      Watchcat::CLI::Config.load("nonexistent.yml")
    end
  end

  def test_default_debounce_value
    Dir.mktmpdir do |tmpdir|
      config_file = File.join(tmpdir, "test_config.yml")

      config_content = <<~YAML
        watches:
          - path: "#{tmpdir}"
            actions:
              - command: "echo 'Test'"
      YAML

      File.write(config_file, config_content)

      config = Watchcat::CLI::Config.load(config_file)
      assert_equal 500, config.watches.first[:debounce]  # Default value
    end
  end
end
