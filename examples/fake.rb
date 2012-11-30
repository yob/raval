# coding: utf-8

# a super simple FTP server with hard coded auth details and only two files
# available for download.
#
# The try it out, run this:
#
#     ruby -Ilib examples/fake.rb

require 'ostruct'
require 'stringio'
require 'raval'

class FakeFTPDriver
  FILE_ONE = "This is the first file available for download.\n\nBy James"
  FILE_TWO = "This is the file number two.\n\n2009-03-21"

  def change_dir(path)
    path == "/" || path == "/files"
  end

  def dir_contents(path)
    case path
    when "/"      then
      [ dir_item("files"), file_item("one.txt", FILE_ONE.bytesize) ]
    when "/files" then
      [ file_item("two.txt", FILE_TWO.bytesize) ]
    else
      []
    end
  end

  def authenticate(user, pass)
    user == "test" && pass == "1234"
  end

  def bytes(path)
    case path
    when "/one.txt"       then FILE_ONE.bytesize
    when "/files/two.txt" then FILE_TWO.bytesize
    else
      false
    end
  end

  def modified_time(path)
    case path
    when "/one.txt"       then Time.now
    when "/files/two.txt" then Time.now - 10000
    else
      false
    end
  end

  def get_file(path)
    case path
    when "/one.txt"       then StringIO.new(FILE_ONE)
    when "/files/two.txt" then StringIO.new(FILE_TWO)
    else
      false
    end
  end

  def put_file(path, tmp_path)
    File.size(tmp_path)
  end

  def delete_file(path)
    false
  end

  def delete_dir(path)
    false
  end

  def rename(from, to)
    false
  end

  def make_dir(path)
    false
  end

  private

  def dir_item(name)
    OpenStruct.new(:name => name, :directory => true, :size => 0)
  end

  def file_item(name, bytes)
    OpenStruct.new(:name => name, :directory => false, :size => bytes)
  end

end

Raval::App.start(:host   => "127.0.0.1",
                 :port   => 3000,
                 :driver => FakeFTPDriver)
