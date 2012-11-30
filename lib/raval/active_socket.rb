# coding: utf-8

require 'celluloid/io'
require 'socket'

module Raval
  # In Active FTP mode, the client opens a listening data socket on their host
  # and we connect to it.
  #
  # A different class is used when operating in passive FTP mode. They both
  # have a #read and #write method, so the quack like each other in the ways
  # that matter.
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
