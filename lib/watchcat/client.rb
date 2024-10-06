module Watchcat
  class Client
    def initialize(uri, paths:, recursive:, force_polling:, poll_interval:)
      puts "start DRb.start_service"
      begin
        DRb.start_service
      rescue => e
        puts "Exception!"
        pp e
      end
      puts "end DRb.start_service"
      @watcher = Watchcat::Watcher.new
      puts "start DRbObject.new_with_uri #{uri}"
      @server = DRbObject.new_with_uri(uri)
      @paths = paths
      @recursive = recursive
      @force_polling = force_polling
      @poll_interval = poll_interval
      puts "end of Client#initialize"
    end

    def run
      puts "Client#run"
      @watcher.watch(
        @paths,
        recursive: @recursive,
        force_polling: @force_polling,
        poll_interval: @poll_interval
      ) { |notification| @server.execute(notification) }
    end
  end
end
