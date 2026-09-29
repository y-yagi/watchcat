module Watchcat
  class StderrLogger
    def error(message)
      $stderr.puts(message)
    end
  end
end
