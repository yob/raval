# coding: utf-8

require "spec_helper"

def handler_with_unauthenticated_user
  connection = double(:connection)

  handler = FTPD::Handler.new(TestDriver.new)
  connection.should_receive(:send_response).with(220, anything)
  handler.new_connection(connection)
  handler
end

def handler_with_authenticated_user
  connection = double(:connection)

  handler = FTPD::Handler.new(TestDriver.new)
  connection.should_receive(:send_response).with(220, anything)
  handler.new_connection(connection)
  connection.should_receive(:send_response).with(331, anything).and_return(331)
  connection.should_receive(:send_response).with(230, anything).and_return(230)
  handler.receive_line("USER test")
  handler.receive_line("PASS 1234")
  handler
end

describe FTPD::Handler, "#new_connection" do

  let(:connection) { double(:connection) }

  subject {
    FTPD::Handler.new(TestDriver.new)
  }

  it "should default to a root name_prefix" do
    connection.should_receive(:send_response).with(220, anything)
    subject.new_connection(connection)
    subject.name_prefix.should eql("/")
  end

  it "should respond with 220 when connection is opened" do
    connection.should_receive(:send_response).with(220, anything)
    subject.new_connection(connection)
  end
end

describe FTPD::Handler, "ALLO" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should always respond with 202 when called" do
      subject.connection.should_receive(:send_response).with(202, anything)
      subject.receive_line("ALLO")
    end
  end
end

describe FTPD::Handler, "USER" do
  context "with an unauthenticated user" do

    subject { handler_with_unauthenticated_user }

    it "should respond with 331 when called by non-logged in user" do
      subject.connection.should_receive(:send_response).with(331, anything)
      subject.receive_line("USER jh")
    end

    it "should respond with 500 when called by a logged in user" do
      subject.connection.should_receive(:send_response).with(331, anything).and_return(331)
      subject.connection.should_receive(:send_response).with(230, anything).and_return(230)
      subject.connection.should_receive(:send_response).with(500, anything).and_return(500)
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("USER test")
    end
  end

end

describe FTPD::Handler, "PASS" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should respond with 202 when called by logged in user" do
      subject.connection.should_receive(:send_response).with(331, anything).and_return(331)
      subject.connection.should_receive(:send_response).with(230, anything).and_return(230)
      subject.connection.should_receive(:send_response).with(202, anything).and_return(202)
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
      subject.receive_line("PASS 1234")
    end

    it "should respond with 553 when called with no param" do
      subject.connection.should_receive(:send_response).with(331, anything).and_return(331)
      subject.connection.should_receive(:send_response).with(553, anything).and_return(553)
      subject.receive_line("USER test")
      subject.receive_line("PASS")
    end

    it "should respond with 530 when called without first providing a username" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("PASS 1234")
    end

    it "should respond with 230 when user is authenticated" do
      subject.connection.should_receive(:send_response).with(331, anything).and_return(331)
      subject.connection.should_receive(:send_response).with(230, anything).and_return(230)
      subject.receive_line("USER test")
      subject.receive_line("PASS 1234")
    end

    it "should respond with 530 when password is incorrect" do
      subject.connection.should_receive(:send_response).with(331, anything).and_return(331)
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("USER test")
      subject.receive_line("PASS 1235")
    end
  end
end

%w(CDUP XCUP).each do |command|

  describe FTPD::Handler, command do
    context "with an unauthenticated user" do
      subject { handler_with_unauthenticated_user }

      it "should respond with 530 if user is not logged in" do
        subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
        subject.receive_line(command)
        subject.name_prefix.should eql("/")
      end
    end
    context "with an authenticated user" do
      subject { handler_with_authenticated_user }

      it "should respond with 250 if called from root dir" do
        subject.connection.should_receive(:send_response).with(250, anything).and_return(250)
        subject.receive_line(command)
        subject.name_prefix.should eql("/")
      end

      it "should respond with 250 if called from inside a dir" do
        subject.connection.should_receive(:send_response).with(250, anything).and_return(250)
        subject.connection.should_receive(:send_response).with(250, anything).and_return(250)
        subject.receive_line("CWD files")
        subject.receive_line(command)
        subject.name_prefix.should eql("/")
      end
    end
  end
end

describe FTPD::Handler, "CWD" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should respond with 530 if user is not logged in" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("CWD")
    end
  end

  context "with an authenticated user" do
    subject { handler_with_authenticated_user }

    it "should respond with 250 if called with '..' from users home" do
      subject.connection.should_receive(:send_response).with(250, anything).and_return(250)
      subject.receive_line("CWD ..")
      subject.name_prefix.should eql("/")
    end

    it "should respond with 250 if called with '.' from users home" do
      subject.connection.should_receive(:send_response).with(250, anything).and_return(250)
      subject.receive_line("CWD .")
      subject.name_prefix.should eql("/")
    end

    it "should respond with 250 if called with '/' from users home" do
      subject.connection.should_receive(:send_response).with(250, anything).and_return(250)
      subject.receive_line("CWD /")
      subject.name_prefix.should eql("/")
    end

    it "should respond with 250 if called with 'files' from users home" do
      subject.connection.should_receive(:send_response).with(250, anything).and_return(250)
      subject.receive_line("CWD files")
      subject.name_prefix.should eql("/files")
    end

    it "should respond with 250 if called with 'files/' from users home" do
      subject.connection.should_receive(:send_response).with(250, anything).and_return(250)
      subject.receive_line("CWD files/")
      subject.name_prefix.should eql("/files")
    end

    it "should respond with 250 if called with '/files/' from users home" do
      subject.connection.should_receive(:send_response).with(250, anything).and_return(250)
      subject.receive_line("CWD /files/")
      subject.name_prefix.should eql("/files")
    end

    it "should respond with 250 if called with '..' from the files dir" do
      subject.connection.should_receive(:send_response).with(250, anything).and_return(250)
      subject.connection.should_receive(:send_response).with(250, anything).and_return(250)
      subject.receive_line("CWD files")
      subject.name_prefix.should eql("/files")
      subject.receive_line("CWD ..")
      subject.name_prefix.should eql("/")
    end

    it "should respond with 250 if called with '/files' from the files dir" do
      subject.connection.should_receive(:send_response).with(250, anything).and_return(250)
      subject.connection.should_receive(:send_response).with(250, anything).and_return(250)
      subject.receive_line("CWD files")
      subject.name_prefix.should eql("/files")
      subject.receive_line("CWD /files")
      subject.name_prefix.should eql("/files")
    end

    it "should respond with 550 if called with unrecognised dir" do
      subject.connection.should_receive(:send_response).with(550, anything).and_return(550)
      subject.receive_line("CWD test")
      subject.name_prefix.should eql("/")
    end
  end
end

describe FTPD::Handler, "DELE" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should respond with 530" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("DELE x")
    end
  end

  context "with an authenticated user" do
    subject { handler_with_authenticated_user }

    it "should respond with 553 when the paramater is omitted" do
      subject.connection.should_receive(:send_response).with(553, anything).and_return(553)
      subject.receive_line("DELE")
    end

    it "should respond with 250 when the file is deleted" do
      subject.connection.should_receive(:send_response).with(250, anything).and_return(250)
      subject.receive_line("DELE four.txt")
    end

    it "should respond with 550 when the file is not deleted" do
      subject.connection.should_receive(:send_response).with(550, anything).and_return(550)
      subject.receive_line("DELE one.txt")
    end
  end
end

describe FTPD::Handler, "HELP" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }
    it "should always respond with 214 when called" do
      subject.connection.should_receive(:send_response).with("214-", anything).and_return("214-")
      subject.connection.should_receive(:send_response)
      subject.connection.should_receive(:send_response).with(214, anything).and_return(214)
      subject.receive_line("HELP")
    end
  end
end

describe FTPD::Handler, "NLST" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }
    it "should respond with 530" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("NLST")
    end
  end

  context "with an authenticated user" do
    subject { handler_with_authenticated_user }

    it "should respond with 150 ...425  when called with no data socket"

    it "should respond with 150 ... 226 when called in the root dir with no param"

    it "should respond with 150 ... 226 when called in the files dir with no param"

    it "should respond with 150 ... 226 when called in the files dir with wildcard (LIST *.txt)"

    it "should respond with 150 ... 226 when called in the subdir with .. param"

    it "should respond with 150 ... 226 when called in the subdir with / param"

    it "should respond with 150 ... 226 when called in the root with files param"

    it "should respond with 150 ... 226 when called in the root with files/ param"

    it "should properly list subdirs etc."
  end
end

describe FTPD::Handler, "LIST" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }
    it "should respond with 530" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("LIST")
    end
  end

  context "with an authenticated user" do
    subject { handler_with_authenticated_user }

    it "should respond with 150 ...425  when called with no data socket"

    it "should respond with 150 ... 226 when called in the root dir with no param"

    it "should respond with 150 ... 226 when called in the files dir with no param"

    it "should respond with 150 ... 226 when called in the files dir with wildcard (LIST *.txt)"

    it "should respond with 150 ... 226 when called in the subdir with .. param"

    it "should respond with 150 ... 226 when called in the subdir with / param"

    it "should respond with 150 ... 226 when called in the root with files param"

    it "should respond with 150 ... 226 when called in the root with files/ param"

    it "should properly list subdirs etc."
  end
end

describe FTPD::Handler, "MKD" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should respond with 530 if user is not logged in" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("MKD x")
    end
  end

  context "with an authenticated user" do
    subject { handler_with_authenticated_user }
    it "should respond with 553 when the paramater is omitted" do
      subject.connection.should_receive(:send_response).with(553, anything).and_return(553)
      subject.receive_line("MKD")
    end

    it "should respond with 257 when the directory is created" do
      subject.connection.should_receive(:send_response).with(257, anything).and_return(257)
      subject.receive_line("MKD four")
    end

    it "should respond with 550 when the directory is not created" do
      subject.connection.should_receive(:send_response).with(550, anything).and_return(550)
      subject.receive_line("MKD five")
    end
  end
end

describe FTPD::Handler, "MODE" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should always respond with 530 when called by user not logged in" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("MODE S")
    end
  end
  context "with an authenticated user" do
    subject { handler_with_authenticated_user }
    it "should respond with 553 when called with no param" do
      subject.connection.should_receive(:send_response).with(553, anything).and_return(553)
      subject.receive_line("MODE")
    end

    it "should always respond with 200 when called with S param" do
      subject.connection.should_receive(:send_response).with(200, anything).and_return(200)
      subject.receive_line("MODE S")
    end

    it "should always respond with 504 when called with non-S param" do
      subject.connection.should_receive(:send_response).with(504, anything).and_return(504)
      subject.receive_line("MODE F")
    end
  end
end

describe FTPD::Handler, "NOOP" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should always respond with 200" do
      subject.connection.should_receive(:send_response).with(200, anything).and_return(200)
      subject.receive_line("NOOP")
    end
  end
end

describe FTPD::Handler, "PASV" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should always respond with 530 when called by user not logged in" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("PASV")
    end
  end
  context "with an authenticated user" do
    subject { handler_with_authenticated_user }

    it "should always respond with 227 after opening the new socket"
  end
end

describe FTPD::Handler, "EPSV" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should always respond with 530 when called by user not logged in" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("EPSV")
    end
  end
  context "with an authenticated user" do
    subject { handler_with_authenticated_user }

    it "should always respond with 229 after opening the new socket"
  end
end

describe FTPD::Handler, "PORT" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should always respond with 530 when called by user not logged in" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("PORT 127,0,0,1,128,12")
    end
  end
  context "with an authenticated user" do
    subject { handler_with_authenticated_user }

    it "should always respond with 200 after opening the new socket"
  end
end

describe FTPD::Handler, "EPRT" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should always respond with 530 when called by user not logged in" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("EPRT -1-127.0.0.1-32000")
    end
  end
  context "with an authenticated user" do
    subject { handler_with_authenticated_user }

    it "should always respond with 200 after opening the new socket"
  end
end

%w(PWD XPWD).each do |command|
  describe FTPD::Handler, command do
    context "with an unauthenticated user" do
      subject { handler_with_unauthenticated_user }

      it "should always respond with 550 (permission denied)" do
        subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
        subject.receive_line(command)
      end
    end

    context "with an authenticated user" do
      subject { handler_with_authenticated_user }
      it 'should always respond with 257 "/" when called from root dir' do
        subject.connection.should_receive(:send_response).with(257, '"/" is the current directory')
        subject.receive_line(command)
      end

      it 'should always respond with 257 "/files" when called from files dir' do
        connection = subject.connection
        connection.should_receive(:send_response).with(250, anything).and_return(250)
        connection.should_receive(:send_response).with(257, '"/files" is the current directory')
        subject.receive_line("CWD files")
        subject.receive_line(command)
      end
    end
  end
end

describe FTPD::Handler, "RETR" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should always respond with 530 when called by user not logged in" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("RETR blah.txt")
    end
  end
  context "with an authenticated user" do
    subject { handler_with_authenticated_user }

    it "should respond with 553 when called with no param" do
      subject.connection.should_receive(:send_response).with(553, anything).and_return(553)
      subject.receive_line("RETR")
    end

    it "should always respond with 551 when called with an invalid file" do
      pending
      subject.receive_line("PASV")
      subject.reset_sent!
      subject.receive_line("RETR blah.txt")
      subject.sent_data.should match(/551.+/)
    end

    it "should always respond with 150..226 when called with valid file" do
      pending
      subject.receive_line("PASV")
      subject.reset_sent!
      subject.receive_line("RETR one.txt")
      subject.sent_data.should match(/150.+226.+/m)
    end

    it "should always respond with 150..226 when called outside files dir with appropriate param" do
      pending
      subject.receive_line("PASV")
      subject.receive_line("RETR files/two.txt")
      subject.sent_data.should match(/150.+226.+/m)
    end
  end
end

describe FTPD::Handler, "REST" do
  context "with an authenticated user" do
    subject { handler_with_authenticated_user }

    it "should always respond with 500" do
      subject.connection.should_receive(:send_response).with(500, anything).and_return(500)
      subject.receive_line("REST")
    end
  end
end

%w(RMD XRMD).each do |command|
  describe FTPD::Handler, command do
    context "with an unauthenticated user" do
      subject { handler_with_unauthenticated_user }

      it "should respond with 530 if user is not logged in" do
        subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
        subject.receive_line("#{command} x")
      end
    end
    context "with an authenticated user" do
      subject { handler_with_authenticated_user }

      it "should respond with 553 when the paramater is omitted" do
        subject.connection.should_receive(:send_response).with(553, anything).and_return(553)
        subject.receive_line("#{command}")
      end

      it "should respond with 250 when the directory is deleted" do
        subject.connection.should_receive(:send_response).with(250, anything).and_return(250)
        subject.receive_line("#{command} four")
      end

      it "should respond with 550 when the directory is not deleted" do
        subject.connection.should_receive(:send_response).with(550, anything).and_return(550)
        subject.receive_line("#{command} x")
      end
    end
  end
end

describe FTPD::Handler, "RNFR" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should respond with 530" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("RNFR x")
    end
  end
  context "with an authenticated user" do
    subject { handler_with_authenticated_user }

    it "should respond with 553 when the paramater is omitted" do
      subject.connection.should_receive(:send_response).with(553, anything).and_return(553)
      subject.receive_line("RNFR")
    end

    it "should always respond with 350 when called" do
      subject.connection.should_receive(:send_response).with(350, anything).and_return(350)
      subject.receive_line("RNFR x")
    end
  end
end

describe FTPD::Handler, "RNTO" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should respond with 530" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("RNTO x")
    end
  end
  context "with an authenticated user" do
    subject { handler_with_authenticated_user }
    it "should respond with 553 when the paramater is omitted" do
      subject.connection.should_receive(:send_response).with(553, anything).and_return(553)
      subject.receive_line("RNTO")
    end

    it "should respond with XXX when the RNFR command is omitted"

    it "should respond with 250 when the file is renamed" do
      subject.connection.should_receive(:send_response).with(350, anything).and_return(350)
      subject.connection.should_receive(:send_response).with(250, anything).and_return(250)
      subject.receive_line("RNFR one.txt")
      subject.receive_line("RNTO two.txt")
    end

    it "should respond with 550 when the file is not renamed" do
      subject.connection.should_receive(:send_response).with(350, anything).and_return(350)
      subject.connection.should_receive(:send_response).with(550, anything).and_return(550)
      subject.receive_line("RNFR two.txt")
      subject.receive_line("RNTO one.txt")
    end
  end
end

describe FTPD::Handler, "QUIT" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should always respond with 221 when called" do
      subject.connection.should_receive(:close)
      subject.connection.should_receive(:send_response).with(221, anything).and_return(221)
      subject.receive_line("QUIT")
    end
  end
end

describe FTPD::Handler, "SIZE" do

  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should always respond with 530" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("SIZE one.txt")
    end
  end

  context "with an authenticated user" do
    subject { handler_with_authenticated_user }
    it "should always respond with 553 when called with no param" do
      subject.connection.should_receive(:send_response).with(553, anything).and_return(553)
      subject.receive_line("SIZE")
    end

    it "should always respond with 450 when called with a directory param" do
      subject.connection.should_receive(:send_response).with(450, anything).and_return(450)
      subject.receive_line("SIZE files")
    end

    it "should always respond with 450 when called with a non-file param" do
      subject.connection.should_receive(:send_response).with(450, anything).and_return(450)
      subject.receive_line("SIZE blah")
    end

    it "should always respond with 213 when called with a valid file param" do
      subject.connection.should_receive(:send_response).with(213, 56).and_return(213)
      subject.receive_line("SIZE one.txt")
    end

    it "should always respond with 213 when called with a valid file param" do
      subject.connection.should_receive(:send_response).with(213, 40).and_return(213)
      subject.receive_line("SIZE files/two.txt")
    end
  end
end

describe FTPD::Handler, "MDTM" do

  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should always respond with 530" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("MDTM one.txt")
    end
  end

  context "with an authenticated user" do
    subject { handler_with_authenticated_user }
    it "should always respond with 553 when called with no param" do
      subject.connection.should_receive(:send_response).with(553, anything).and_return(553)
      subject.receive_line("MDTM")
    end

    it "should always respond with 450 when called with a directory param" do
      subject.connection.should_receive(:send_response).with(450, anything).and_return(450)
      subject.receive_line("MDTM files")
    end

    it "should always respond with 450 when called with a non-file param" do
      subject.connection.should_receive(:send_response).with(450, anything).and_return(450)
      subject.receive_line("MDTM blah")
    end

    it "should always respond with 213 when called with a valid file param" do
      subject.connection.should_receive(:send_response).with(213, "20121010101000").and_return(213)
      subject.receive_line("MDTM one.txt")
    end

    it "should always respond with 213 when called with a valid file param" do
      subject.connection.should_receive(:send_response).with(213, "20121111111100").and_return(213)
      subject.receive_line("MDTM files/two.txt")
    end
  end
end

describe FTPD::Handler, "STOR" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should always respond with 530 when called by user not logged in" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("STOR blah.txt")
    end
  end
  context "with an authenticated user" do
    subject { handler_with_authenticated_user }

    it "should respond with 553 when called with no param" do
      subject.connection.should_receive(:send_response).with(553, anything).and_return(553)
      subject.receive_line("STOR")
    end

    it "should respond with 150...206 after a successful transfer"
  end
end

describe FTPD::Handler, "STRU" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should always respond with 530" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("STRU F")
    end
  end

  context "with an authenticated user" do
    subject { handler_with_authenticated_user }
    it "should respond with 553 when called with no param" do
      subject.connection.should_receive(:send_response).with(553, anything).and_return(553)
      subject.receive_line("STRU")
    end

    it "should always respond with 200 when called with F param" do
      subject.connection.should_receive(:send_response).with(200, anything).and_return(200)
      subject.receive_line("STRU F")
    end

    it "should always respond with 504 when called with non-F param" do
      subject.connection.should_receive(:send_response).with(504, anything).and_return(504)
      subject.receive_line("STRU S")
    end
  end
end

describe FTPD::Handler, "SYST" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should always respond with 530" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("SYST")
    end
  end

  context "with an authenticated user" do
    subject { handler_with_authenticated_user }

    it "should respond with 215 when called by a logged in user" do
      subject.connection.should_receive(:send_response).with(215, "UNIX Type: L8").and_return(215)
      subject.receive_line("SYST")
    end
  end
end

describe FTPD::Handler, "TYPE" do
  context "with an unauthenticated user" do
    subject { handler_with_unauthenticated_user }

    it "should always respond with 530" do
      subject.connection.should_receive(:send_response).with(530, anything).and_return(530)
      subject.receive_line("TYPE A")
    end
  end

  context "with an authenticated user" do
    subject { handler_with_authenticated_user }

    it "should respond with 553 when called with no param" do
      subject.connection.should_receive(:send_response).with(553, anything).and_return(553)
      subject.receive_line("TYPE")
    end

    it "should respond with 200 when called with 'A' by a logged in user" do
      subject.connection.should_receive(:send_response).with(200, /ASCII/).and_return(200)
      subject.receive_line("TYPE A")
    end

    it "should respond with 200 when called with 'I' by a logged in user" do
      subject.connection.should_receive(:send_response).with(200, /binary/).and_return(200)
      subject.receive_line("TYPE I")
    end

    it "should respond with 500 when called by a logged in user with un unrecognised param" do
      subject.connection.should_receive(:send_response).with(500, anything).and_return(500)
      subject.receive_line("TYPE T")
    end
  end
end
