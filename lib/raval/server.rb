# coding: utf-8

require 'celluloid/io'
require 'raval/handler'
require 'raval/connection'

module Raval
  # The beginning of things. Listens on a TCP socket for incoming connections
  # and spins off a new agent to handle each connection.
  class Server
    include Celluloid::IO

    def initialize(host, port, driver, driver_opts)
      @driver, @driver_opts = driver, driver_opts
      # Since we included Celluloid::IO, we're actually making a
      # Celluloid::IO::TCPServer here
      @server = TCPServer.new(host, port)
      run!
    rescue Errno::EACCES
      $stderr.puts "Unable to listen on port #{port}"
      exit
    end

    def finalize
      @server.close if @server
    end

    def run
      loop { handle_connection! @server.accept }
    end

    def handle_connection(socket)
      if @driver_opts
        driver = @driver.new(@driver_opts)
      else
        driver = @driver.new
      end
      handler = Handler.new(driver)
      connection = Connection.new(handler, socket)
      connection.read_commands
    rescue EOFError, IOError
      puts "*** #{connection.host}:#{connection.port} disconnected"
    end
  end
end
