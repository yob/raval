# coding: utf-8

require 'ftpd/active_socket'
require 'ftpd/passive_socket'
require 'stringio'
require 'tempfile'

module FTPD
  class Handler

    COMMANDS = %w[quit type user retr stor eprt port cdup cwd dele rmd pwd
                  list size syst mkd pass xcup xpwd xcwd xrmd rest allo nlst
                  pasv epsv help noop mode rnfr rnto stru feat]

    def initialize(driver)
      @driver = driver
    end

    def new_connection(connection)
      @mode   = :binary
      @user   = nil
      @name_prefix = "/"
      @connection = connection
      @connection.send_response(220, "FTP server (celluloid-ftpd) ready")
    end

    def receive_line(line)
      cmd, param = parse_request(line)

      # if the command is contained in the whitelist, and there is a method
      # to handle it, call it. Otherwise send an appropriate response to the
      # client
      if COMMANDS.include?(cmd) && self.respond_to?("cmd_#{cmd}".to_sym, true)
        self.__send__("cmd_#{cmd}".to_sym, param)
      else
        @connection.send_response(500, "Sorry, I don't understand #{cmd.upcase}")
      end
    end

    def cmd_allo(param)
      @connection.send_response(202, "Obsolete")
    end

    # handle the HELP FTP command by sending a list of available commands.
    def cmd_help(param)
      @connection.send_response("214-", "The following commands are recognized.")
      commands = COMMANDS
      str = ""
      commands.sort.each_slice(3) { |slice|
        str += "     " + slice.join("\t\t") + FTPD::LBRK
      }
      @connection.send_data(str)
      @connection.send_response(214, "End of list.")
    end

    # the original FTP spec had various options for hosts to negotiate how data
    # would be sent over the data socket, In reality these days (S)tream mode
    # is all that is used for the mode - data is just streamed down the data
    # socket unchanged.
    #
    def cmd_mode(param)
      send_unauthorised and return unless logged_in?
      send_param_required and return if param.nil?
      if param.upcase.eql?("S")
        @connection.send_response(200, "OK")
      else
        @connection.send_response(504, "MODE is an obsolete command")
      end
    end

    # handle the NOOP FTP command. This is essentially a ping from the client
    # so we just respond with an empty 200 message.
    def cmd_noop(param)
      @connection.send_response(200, "")
    end

    # handle the QUIT FTP command by closing the connection
    def cmd_quit(param)
      @connection.send_response(221, "Bye")
      @connection.close
    end

    # like the MODE and TYPE commands, stru[cture] dates back to a time when the FTP
    # protocol was more aware of the content of the files it was transferring, and
    # would sometimes be expected to translate things like EOL markers on the fly.
    #
    # These days files are sent unmodified, and F(ile) mode is the only one we
    # really need to support.
    def cmd_stru(param)
      send_param_required and return if param.nil?
      send_unauthorised and return unless logged_in?
      if param.upcase.eql?("F")
        @connection.send_response(200, "OK")
      else
        @connection.send_response(504, "STRU is an obsolete command")
      end
    end

    # return the name of the server
    def cmd_syst(param)
      send_unauthorised and return unless logged_in?
      @connection.send_response(215, "UNIX Type: L8")
    end

    # like the MODE and STRU commands, TYPE dates back to a time when the FTP
    # protocol was more aware of the content of the files it was transferring, and
    # would sometimes be expected to translate things like EOL markers on the fly.
    #
    # Valid options were A(SCII), I(mage), E(BCDIC) or LN (for local type). Since
    # we plan to just accept bytes from the client unchanged, I think Image mode is
    # adequate. The RFC requires we accept ASCII mode however, so accept it, but
    # ignore it.
    def cmd_type(param)
      send_unauthorised and return unless logged_in?
      send_param_required and return if param.nil?
      if param.upcase.eql?("A")
        @connection.send_response(200, "Type set to ASCII")
      elsif param.upcase.eql?("I")
        @connection.send_response(200, "Type set to binary")
      else
        @connection.send_response(500, "Invalid type")
      end
    end

    # handle the USER FTP command. This is a user attempting to login.
    # we simply store the requested user name as an instance variable
    # and wait for the password to be submitted before doing anything
    def cmd_user(param)
      send_param_required and return if param.nil?
      @connection.send_response(500, "Already logged in") and return unless @user.nil?
      @requested_user = param
      @connection.send_response(331, "OK, password required")
    end

    # handle the PASS FTP command. This is the second stage of a user logging in
    def cmd_pass(param)
      @connection.send_response(202, "User already logged in") and return unless @user.nil?
      send_param_required and return if param.nil?
      @connection.send_response(530, "password with no username") and return if @requested_user.nil?

      if @driver.authenticate(@requested_user, param)
        @name_prefix = "/"
        @user = @requested_user
        @requested_user = nil
        @connection.send_response(230, "OK, password correct")
      else
        @user = nil
        @connection.send_response(530, "incorrect login. not logged in.")
      end
    end

    # Passive FTP. At the clients request, listen on a port for an incoming
    # data connection. The listening socket is opened on a random port, so
    # the host and port is sent back to the client on the control socket.
    #
    def cmd_pasv(param)
      send_unauthorised and return unless logged_in?

      host, port = start_passive_socket

      p1, p2 = *port.divmod(256)

      @connection.send_response(227, "Entering Passive Mode (" + host.split(".").join(",") + ",#{p1},#{p2})")
    end

    # listen on a port, see RFC 2428
    #
    def cmd_epsv(param)
      host, port = start_passive_socket

      send_response "229 Entering Extended Passive Mode (|||#{port}|)"
    end

    # Active FTP. An alternative to Passive FTP. The client has a listening socket
    # open, waiting for us to connect and establish a data socket. Attempt to
    # open a connection to the host and port they specify and save the connection,
    # ready for either end to send something down it.
    def cmd_port(param)
      send_unauthorised and return unless logged_in?
      send_param_required and return if param.nil?

      nums = param.split(',')
      port = nums[4].to_i * 256 + nums[5].to_i
      host = nums[0..3].join('.')
      close_datasocket

      @datasocket = ActiveSocket.new(host, port)
      @datasocket.async.connect
      wait_for_datasocket do
        @connection.send_response(200, "Connection established (#{port})")
      end

    rescue => e
      puts "Error opening data connection to #{host}:#{port}"
      puts e.inspect
      @connection.send_response(425, "Data connection failed")
    end

    # go up a directory, really just an alias
    def cmd_cdup(param)
      send_unauthorised and return unless logged_in?
      cmd_cwd("..")
    end

    # As per RFC1123, XCUP is a synonym for CDUP
    alias cmd_xcup cmd_cdup

    # change directory
    def cmd_cwd(param)
      send_unauthorised and return unless logged_in?
      path = build_path(param)

      if @driver.change_dir(path)
        @name_prefix = path
        @connection.send_response(250, "Directory changed to #{path}")
      else
        send_permission_denied
      end
    end

    # As per RFC1123, XCWD is a synonym for CWD
    alias cmd_xcwd cmd_cwd

    # make directory
    def cmd_mkd(param)
      send_unauthorised and return unless logged_in?
      send_param_required and return if param.nil?

      if @driver.make_dir(build_path(param))
        @connection.send_response(257, "Directory created")
      else
        send_action_not_taken
      end
    end

    # return the current directory
    def cmd_pwd(param)
      send_unauthorised and return unless logged_in?
      @connection.send_response(257, "\"#{@name_prefix}\" is the current directory")
    end

    # As per RFC1123, XPWD is a synonym for PWD
    alias cmd_xpwd cmd_pwd

    # delete a directory
    def cmd_rmd(param)
      send_unauthorised and return unless logged_in?
      send_param_required and return if param.nil?

      if @driver.delete_dir(build_path(param))
        @connection.send_response "250 Directory deleted."
      else
        send_action_not_taken
      end
    end

    # As per RFC1123, XRMD is a synonym for RMD
    alias cmd_xrmd cmd_rmd

    # return a listing of the current directory, one per line, each line
    # separated by the standard FTP EOL sequence. The listing is returned
    # to the client over a data socket.
    #
    def cmd_nlst(param)
      send_unauthorised and return unless logged_in?
      @connection.send_response(150, "Opening ASCII mode data connection for file list")

      files = @driver.dir_contents(build_path(param)).map(&:name)
      send_outofband_data(files)
    end

    # return a detailed list of files and directories
    def cmd_list(param)
      send_unauthorised and return unless logged_in?
      @connection.send_response(150, "Opening ASCII mode data connection for file list")

      param = '' if param.to_s == '-a'

      files = @driver.dir_contents(build_path(param))
      now = Time.now
      lines = files.map { |item|
        sizestr = (item.size || 0).to_s.rjust(12)
        "#{item.directory ? 'd' : '-'}#{item.permissions || 'rwxrwxrwx'} 1 #{item.owner || 'owner'}  #{item.group || 'group'} #{sizestr} #{(item.time || now).strftime("%b %d %H:%M")} #{item.name}"
      }
      send_outofband_data(lines)
    end

    # delete a file
    def cmd_dele(param)
      send_unauthorised and return unless logged_in?
      send_param_required and return if param.nil?

      path = build_path(param)

      if @driver.delete_file(path)
        @connection.send_response(250, "File deleted")
      else
        send_action_not_taken
      end
    end

    # resume downloads
    def cmd_rest(param)
      @connection.send_response(500, "Feature not implemented")
    end

    # send a file to the client
    def cmd_retr(param)
      send_unauthorised and return unless logged_in?
      send_param_required and return if param.nil?

      path = build_path(param)

      io = @driver.get_file(path)
      if io
        @connection.send_response(150, "Data transfer starting #{io.size} bytes")
        send_outofband_data(io)
      else
        @connection.send_response(551, "file not available")
      end
    end

    # rename a file
    def cmd_rnfr(param)
      send_unauthorised and return unless logged_in?
      send_param_required and return if param.nil?

      @from_filename = build_path(param)
      @connection.send_response(350, "Requested file action pending further information.")
    end

    # rename a file
    def cmd_rnto(param)
      send_unauthorised and return unless logged_in?
      send_param_required and return if param.nil?

      if @driver.rename(@from_filename, build_path(param))
        @connection.send_response(250, "File renamed.")
      else
        send_action_not_taken
      end
    end

    # return the size of a file in bytes
    def cmd_size(param)
      send_unauthorised and return unless logged_in?
      send_param_required and return if param.nil?

      bytes = @driver.bytes(build_path(param))
      if bytes
        @connection.send_response(213, bytes)
      else
        @connection.send_response(450, "file not available")
      end
    end

    # save a file from a client
    def cmd_stor(param)
      send_unauthorised and return unless logged_in?
      send_param_required and return if param.nil?

      path = build_path(param)

      if @driver.respond_to?(:put_file_streamed)
        cmd_stor_streamed(path)
      elsif @driver.respond_to?(:put_file)
        cmd_stor_tempfile(path)
      else
        raise "driver MUST respond to put_file OR put_file_streamed"
      end
    end

    def cmd_stor_streamed(target_path)
      if @datasocket
        @connection.send_response(150, "Data transfer starting")
        @driver.put_file_streamed(target_path, @datasocket) do |bytes|
          if bytes
            @connection.send_response(200, "OK, received #{bytes} bytes")
          else
            send_action_not_taken
          end
        end
      else
        @connection.send_response(425, "Error establishing connection")
      end
    end

    def cmd_stor_tempfile(target_path)
      Tempfile.open("celluloid-ftpd") do |tmpfile|
        tmpfile.binmode

        @connection.send_response(150, "Data transfer starting")
        while chunk = @datasocket.read
          tmpfile.write(chunk)
        end
        tmpfile.flush
        tmpfile.close
        bytes = @driver.put_file(target_path, tmpfile.path)
        if bytes
          @connection.send_response(200, "OK, received #{bytes} bytes")
        else
          send_action_not_taken
        end
      end
    end

    private

    def build_path(filename = nil)
      if filename && filename[0,1] == "/"
        path = File.expand_path(filename)
      elsif filename && filename != '-a'
        path = File.expand_path("#{@name_prefix}/#{filename}")
      else
        path = File.expand_path(@name_prefix)
      end
      path.gsub(/\/+/,"/")
    end

    # send data to the client across the data socket.
    #
    def send_outofband_data(data)
      wait_for_datasocket do |datasocket|
        if datasocket.nil?
          @connection.send_response(425, "Error establishing connection")
          return
        end

        if data.is_a?(Array)
          data = data.join(LBRK) << LBRK
        end
        data = StringIO.new(data) if data.kind_of?(String)

        # blocks until all data is sent
        begin
          bytes = 0
          data.each do |line|
            datasocket.write(line)
            bytes += line.bytesize
          end
          @connection.send_response(226, "Closing data connection, sent #{bytes} bytes")
        rescue => e
          puts e.inspect
        ensure
          close_datasocket
          data.close if data.respond_to?(:close)
        end
      end
    end

    def start_passive_socket
      # close any existing data socket
      close_datasocket

      # open a listening socket on the appropriate host
      # and on a random port
      @datasocket = PassiveSocket.new(@connection.myhost)

      [@connection.myhost, @datasocket.port]
    end

    # split a client's request into command and parameter components
    def parse_request(data)
      data.strip!
      space = data.index(" ")
      if space
        cmd = data[0, space]
        param = data[space+1, data.length - space]
        param = nil if param.strip.size == 0
      else
        cmd = data
        param = nil
      end

      [cmd.downcase, param]
    end

    def close_datasocket
      if @datasocket
        @datasocket.close
        @datasocket.terminate
        @datasocket = nil
      end

      # stop listening for data socket connections, we have one
      #if @listen_sig
      #  PassiveSocket.stop(@listen_sig)
      #  @listen_sig = nil
      #end
    end

    # waits for the data socket to be established
    def wait_for_datasocket(interval = 0.1, &block)
      if (@datasocket.nil? || !@datasocket.connected?) && interval < 25
        sleep interval
        wait_for_datasocket(interval * 2, &block)
        return
      end
      if @datasocket.connected?
        yield @datasocket
      else
        yield nil
      end
    end

    def logged_in?
      @user.nil? ? false : true
    end

    def send_param_required
      @connection.send_response(553, "action aborted, required param missing")
    end

    def send_permission_denied
      @connection.send_response(550, "Permission denied")
    end

    def send_action_not_taken
      @connection.send_response(550, "Action not taken")
    end

    def send_illegal_params
      @connection.send_response(553, "action aborted, illegal params")
    end

    def send_unauthorised
      @connection.send_response(530, "Not logged in")
    end
  end
end
