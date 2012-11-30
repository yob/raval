# coding: utf-8

# A FTP proxy to a cloud storage provider. Uses the fog gem to interface
# with the storage APIs.
#
# Any user will be permitted to log in with any password, but they are
# sandboxed to their own files. In the real world you will probably want to
# use real passwords.
#
# The try it out:
#
# 1) create an empty bucket/container with your cloud storage provider
# 2) edit the driver_options hash at the bottom of the file
# 3) run this:
#
#     ruby -Ilib examples/fog.rb

require 'ostruct'
require 'stringio'
require 'raval'
require 'fog'

class FogFTPDriver

  def initialize(options = {})
    @options = options
  end

  def change_dir(path)
    prefix = scoped_path_with_trailing_slash(path)
    files = directory.files.all(:prefix => prefix)
    files.any?
  end

  def dir_contents(path)
    prefix = scoped_path_with_trailing_slash(path)
    directories = []
    files = []
    directory.files.all(:prefix => prefix).each do |file|
      tail     = file.key.sub(prefix,"")
      depth    = tail.split("/").size
      basename = tail.split("/").first
      if depth == 1 && basename != ".placeholder"
        files << file_item(basename, file.content_length)
      elsif depth > 1 && directories.none? { |d| d.name == basename }
        directories << dir_item(basename)
      end
    end
    (directories + files).sort_by(&:name)
  end

  def authenticate(user, pass)
    @user = user
    true
  end

  def bytes(path)
    prefix = scoped_path(path)
    file = directory.files.head(prefix)
    if file
      file.content_length
    else
      nil
    end
  end

  def modified_time(path)
    prefix = scoped_path(path)
    file = directory.files.head(prefix)
    if file
      file.last_modified
    else
      nil
    end
  end

  def get_file(path)
    prefix = scoped_path(path)
    file = directory.files.get(prefix)
    if file
      file.body
    else
      nil
    end
  end

  def put_file(path, tmp_path)
    key = scoped_path(path)
    File.open(tmp_path, "rb") do |io|
      directory.files.create(:key  => key,
                             :body => io)
    end
    File.size(tmp_path)
  end

  def delete_file(path)
    prefix = scoped_path(path)
    file = directory.files.head(prefix)
    if file
      file.destroy
    else
      nil
    end
  end

  def delete_dir(path)
    prefix = scoped_path_with_trailing_slash(path)
    files = directory.files.all(:prefix => prefix)

    if files.size == 1 && files.first.key[-12,12] == ".placeholder"
      file = directory.files.get("#{prefix}.placeholder")
      file.destroy
    else
      false
    end
  end

  def rename(from, to)
    scoped_from = scoped_path(from)
    scoped_to   = scoped_path(to)
    old_file = directory.files.head(scoped_from)
    if old_file
      storage.copy_object(directory.key,scoped_from,directory.key,scoped_to)
      old_file.destroy
    else
      nil
    end
  end

  def make_dir(path)
    prefix = scoped_path_with_trailing_slash(path)
    files = directory.files.all(:prefix => prefix)
    if files.any?
      false # the dir already exists
    else
      # upload a placeholder file so the directory "exists"
      directory.files.create(:key  => "#{prefix}.placeholder",
                             :body => ".placeholder")
      true
    end
  end

  private

  def storage
    @storage ||= Fog::Storage.new(@options.reject { |k,_| k == :directory})
  end

  def directory
    @directory ||= storage.directories.get(@options[:directory])
  end

  def dir_item(name)
    OpenStruct.new(:name => name,
                   :directory => true,
                   :size => 0,
                   :owner => "user",
                   :group => "group",
                   :time  => Time.now,
                   :permissions => "r--r--r--")
  end

  def file_item(name, bytes)
    OpenStruct.new(:name => name,
                   :directory => false,
                   :size => bytes,
                   :owner => "user",
                   :group => "group",
                   :time  => Time.now,
                   :permissions => "r--r--r--")
  end

  def scoped_path_with_trailing_slash(path)
    path  = scoped_path(path)
    path += "/" if path[-1,1] != "/"
    path == "/" ? nil : path
  end

  def scoped_path(path)
    path = "" if path == "/"

    File.join("/", @user, path)[1,1024]
  end

end

driver_opts = {:rackspace_username => 'RACKSPACE_USER',
               :rackspace_api_key  => 'RACKSPACE_KEY',
               :provider           => 'Rackspace',
               :directory          => 'RACKSPACE_CONTAINER'}

Raval::App.start(:host   => "127.0.0.1",
                 :port   => 3000,
                 :driver => FogFTPDriver,
                 :driver_opts => driver_opts
                )
