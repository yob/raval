# coding: utf-8

# a super simple driver that is used in our specs

require 'ostruct'
require 'stringio'

class TestDriver
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
    path == "/four.txt"
  end

  def delete_dir(path)
    path == "/four"
  end

  def rename(from, to)
    from == "/one.txt"
  end

  def make_dir(path)
    path == "/four"
  end

  private

  def dir_item(name)
    OpenStruct.new(:name => name, :directory => true, :size => 0)
  end

  def file_item(name, bytes)
    OpenStruct.new(:name => name, :directory => false, :size => bytes)
  end

end
