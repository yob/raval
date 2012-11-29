# coding: utf-8

module FTPD
  # converts a list of objects that describe the contents of a directory and
  # formats them to be valid responses to the LIST or NLST FTP commands.
  class ListFormatter
    def initialize(files)
      @files = check_duck_type(files)
    end

    # response to the NLST command
    #
    def short
      @files.map(&:name)
    end

    # response to the LIST command
    #
    def detailed
      now = Time.now
      @files.map { |item|
        sizestr = (item.size || 0).to_s.rjust(12)
        "#{item.directory ? 'd' : '-'}#{item.permissions || 'rwxrwxrwx'} 1 #{item.owner || 'owner'}  #{item.group || 'group'} #{sizestr} #{(item.time || now).strftime("%b %d %H:%M")} #{item.name}"
      }
    end

    private

    def check_duck_type(files)
      files.each do |file|
        file.respond_to?(:directory)   || raise(ArgumentError, "file must respond to #directory")
        file.respond_to?(:size)        || raise(ArgumentError, "file must respond to #size")
        file.respond_to?(:permissions) || raise(ArgumentError, "file must respond to #permissions")
        file.respond_to?(:owner)       || raise(ArgumentError, "file must respond to #owner")
        file.respond_to?(:group)       || raise(ArgumentError, "file must respond to #group")
        file.respond_to?(:time)        || raise(ArgumentError, "file must respond to #time")
        file.respond_to?(:name)        || raise(ArgumentError, "file must respond to #name")
      end
    end
  end
end
