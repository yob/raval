# coding: utf-8

module Raval
  # wraps a raw TCP socket and simplifies working with FTP style data.
  #
  # FTP commands and responses are always a single line ending in a line break,
  # so make it easy to read and write single lines.
  class Connection

    BUFFER_SIZE = 1024

    attr_reader :port,   :host
    attr_reader :myport, :myhost

    def initialize(handler, socket)
      @socket, @handler = socket, handler
      _, @port, @host = socket.peeraddr
      _, @myport, @myhost = socket.addr
      handler.new_connection(self)
      puts "*** Received connection from #{host}:#{port}"
    end

    def send_data(str)
      @socket.write(str)
    end

    def send_response(code, message)
      @socket.write("#{code} #{message}#{Raval::LBRK}")
    end

    # Close the connection
    def close
      @socket.close
    end

    def read_commands
      input = ""
      while true
        input << @socket.readpartial(BUFFER_SIZE)
        match = input.match(/(^.+\r\n)/)
        if match
          line  = match[1]
          input = input[line.bytesize, line.bytesize]
          @handler.receive_line(line)
        end
      end
    end

  end
end
