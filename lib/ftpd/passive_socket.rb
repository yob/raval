# coding: utf-8

require 'celluloid/io'

module FTPD
  class PassiveSocket
    include Celluloid::IO

    attr_reader :port

    def initialize(host)
      @host = host
      @socket = nil
      puts "*** Starting passive socket on #{host}"

      # TODO ::TcpServer#addr exists, but Celluloid::IO::TcpServer#addr does
      #      not. Once that's fixed, make this port random by replacing 30000
      #      with 0
      @server = TCPServer.new(@host, 30000)
      #@port = @server.addr[1]
      @port = 30000
      run!
    end

    def run
      handle_connection @server.accept
    end

    def read
      raise "socket not connected" unless @socket
      @socket.readpartial(4096)
    rescue EOFError, Errno::ECONNRESET
      close
      nil
    end

    def write(data)
      raise "socket not connected" unless @socket
      @socket.write(data)
    end

    def connected?
      @socket != nil
    end

    def close
      @socket.close if @socket
      @socket = nil
      @server.close if @server
      @server = nil
    end

    private

    def handle_connection(socket)
      @socket = socket
      @server.close
      @server = nil
    rescue EOFError, IOError
      puts "*** passive socket disconnected"
    end
  end
end