# coding: utf-8

module FTPD
  # converts a list of objects that describe the contents of a directory and
  # formats them to be valid responses to the LIST or NLST FTP commands.
  class ListFormatter
    def initialize(files)
      @files = files
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
  end
end
