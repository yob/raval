# coding: utf-8

require 'celluloid/io'
require 'socket'

module FTPD
  class ActiveSocket
    include Celluloid::IO

    def initialize(host, port)
      @host, @port = host, port
      @socket = nil
    end

    def connect
      unless @socket
        @socket = ::TCPSocket.new(@host, @port)
      end
    end

    def read
      connect unless @socket
      @socket.readpartial(4096)
    rescue EOFError, Errno::ECONNRESET
      close
      nil
    end

    def write(data)
      connect unless @socket
      @socket.write(data)
    end

    def connected?
      @socket != nil
    end

    def close
      @socket.close
      @socket = nil
    end
  end
end
