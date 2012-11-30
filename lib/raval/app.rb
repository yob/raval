# coding: utf-8

module Raval

  # Holds the logic for booting a raval server and configuring the
  # process as required, binding to a port, writing a pid file, etc.
  #
  # Use it like so:
  #
  #    Raval::App.start(:port => 3000)
  #
  # Options:
  #
  #     :driver - the driver class that implements persistance
  #     :host - the host IP to listen on. [default: 127.0.0.1]
  #     :port - the TCP port to listen on [default: 21]
  #     :pid_file - a path to write the process pid to. Useful for monitoring
  #     :uid - the user ID to change the process owner to
  #     :gid - the group ID to change the process owner to
  #     :name - an optional name to place in the process description
  class App

    def initialize(options = {})
      @options = options
    end

    def self.start(options = {})
      self.new(options).start
    end

    def start
      update_procline

      puts "Starting ftp server on 0.0.0.0:#{port}"
      Raval::Server.supervise(host,port, driver)

      write_pid
      change_gid
      change_uid
      setup_signal_handlers
      sleep # for ever
    end

    private

    def name
      @options[:name]
    end

    def host
      @options.fetch(:host, "127.0.0.1")
    end

    def port
      @options.fetch(:port, 21)
    end

    def driver
      @options.fetch(:driver)
    rescue KeyError
      raise ArgumentError, "the :driver option must be provided"
    end

    def uid
      @options[:uid]
    end

    def gid
      @options[:gid]
    end

    def pid_file
      @options[:pid_file]
    end

    def write_pid
      if pid_file
        File.open(pid_file, "w") { |io| io.write pid }
      end
    end

    def update_procline
      if name
        $0 = "raval ftpd [#{name}]"
      else
        $0 = "raval"
      end
    end

    def change_gid
      if gid && Process.gid == 0
        Process.gid = gid
      end
    end

    def change_uid
      if uid && Process.euid == 0
        Process::Sys.setuid(uid)
      end
    end

    def setup_signal_handlers
=begin
      trap('QUIT') do
        EM.stop
      end
      trap('TERM') do
        EM.stop
      end
      trap('INT') do
        EM.stop
      end
=end
    end

  end
end
