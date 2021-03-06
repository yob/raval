# raval

An experimental FTP server framework built on top of Celluloid. Celluloid is a
concurrency library that uses threads, so you will get the best results by
using jruby or rubinius.

By providing a simple driver class that responds to a handful of methods you
can have a complete FTP server.

The library is extracted from real world situations where an FTP interface was
required to sit in front of a non-filesystem persistence layer.

Some sample use cases include persisting data to:

* an Amazon S3 bucket
* a relational database
* redis
* memory

The examples directory contains a demonstration of in memory persistence.

## Installation

    gem install raval

## Usage

To boot an FTP server you will need to provide a driver that speaks to your
persistence layer - the required driver contract is listed below.

Once that's ready, boot a new server like so:

    require 'raval'

    class MyDriver
      .. implementation here ..
    end

    Raval::App.start(:host   => "127.0.0.1",
                     :port   => 3000,
                     :driver => MyDriver)

To get started quickly, try out the example in the git repo like so:

    ruby -Ilib examples/fake.rb

### The Driver Contract

The driver MUST have the following methods.  Each method MUST accept the listed
parameters and return an appropriate value:

    authenticate(user, pass)
    - boolean indicating if the provided details are valid

    bytes(path)
    - an integer with the number of bytes in the file or nil if the file
      doesn't exist

    modified_time(path)
    - a Time-ish object indicating when the requested path was last modified, or
      nil if the file doesn't exist

    change_dir(path)
    - a boolean indicating if the current user is permitted to change to the
      requested path

    dir_contents(path)
    - an array of the contents of the requested path or nil if the dir
      doesn't exist. Each entry in the array should meet the Entry contract
      defined below.

    delete_dir(path)
    - a boolean indicating if the directory was successfully deleted

    delete_file(path)
    - a boolean indicating if path was successfully deleted

    rename(from_path, to_path)
    - a boolean indicating if from_path was successfully renamed to to_path

    make_dir(path)
    - a boolean indicating if path was successfully created as a new directory

    get_file(path)
    - nil if the user isn't permitted to access that path
    - an IOish (File, StringIO, IO, etc) object with data to send back to the
      client

The driver MUST have one of the following methods. Each method MUST accept the
listed parameters and return an appropriate value:

    put_file(path, tmp_file_path)
    - an integer indicating the number of bytes received or False if there
      was an error

    put_file_streamed(path, datasocket)
    - an integer indicating the number of bytes received or False if there
      was an error

### The File Entry Contract

The Driver#dir_contents method must return an array of Entry objects that
describe each item in a directory. Each of these Entry objects MUST have
the following methods and return values. All methods (except name) can
return nil if you're happy for raval to use a reasonable default.

    directory
    - a boolean indicating if the entry is a directory

    size
    - the number of bytes in a file. 0 if the entry is a directory

    permissions
    - a string describing the current users permissions on the entry

    owner
    - the name of the user that owns the entry

    group
    - the name of the group that owns the entry

    time
    - a Time-ish object that indicates when the entry was last modified

    name
    - the name of the file or directory

### Driver Options

Some drivers may need configuration options - for server addresses or usernames
or whatever. To do so, just write your driver constructor to accept an options
hash, and then use it like so:

    require 'raval'

    class MyDriver
      def initialize(opts = {})

      end

      .. remaining implementation here ..
    end

    Raval::App.start(:host   => "127.0.0.1",
                     :port   => 3000,
                     :driver => MyDriver,
                     :driver_opts => {:foo => :bar})

You can see an example of driver options in examples/fog.rb.

## Contributors

* James Healy <james@yob.id.au> [http://www.yob.id.au](http://www.yob.id.au)
* John Nunemaker <nunemaker@gmail.com>
* Elijah Miller <elijah.miller@gmail.com>

## Warning

FTP is an incredibly insecure protocol. Be careful about forcing users to authenticate
with a username or password that are important.

## License

This library is distributed under the terms of the MIT License. See the included file for
more detail.

## Contributing

All suggestions and patches welcome, preferably via a git repository I can pull from.
If this library proves useful to you, please let me know.

## Further Reading

There are a range of RFCs that together specify the FTP protocol. In chronological
order, the more useful ones are:

* [http://tools.ietf.org/rfc/rfc959.txt](http://tools.ietf.org/rfc/rfc959.txt)
* [http://tools.ietf.org/rfc/rfc1123.txt](http://tools.ietf.org/rfc/rfc1123.txt)
* [http://tools.ietf.org/rfc/rfc2228.txt](http://tools.ietf.org/rfc/rfc2228.txt)
* [http://tools.ietf.org/rfc/rfc2389.txt](http://tools.ietf.org/rfc/rfc2389.txt)
* [http://tools.ietf.org/rfc/rfc2428.txt](http://tools.ietf.org/rfc/rfc2428.txt)
* [http://tools.ietf.org/rfc/rfc3659.txt](http://tools.ietf.org/rfc/rfc3659.txt)
* [http://tools.ietf.org/rfc/rfc4217.txt](http://tools.ietf.org/rfc/rfc4217.txt)

For an english summary that's somewhat more legible than the RFCs, and provides
some commentary on what features are actually useful or relevant 24 years after
RFC959 was published:

* [http://cr.yp.to/ftp.html](http://cr.yp.to/ftp.html)

For a history lesson, check out Appendix III of RCF959. It lists the preceding
(obsolete) RFC documents that relate to file transfers, including the ye old
RFC114 from 1971, "A File Transfer Protocol"

For more information on Celluloid, a library that (among other things) simplifies
writing applications that use sockets, check out their website.

* [http://celluloid.io/](http://celluloid.io/)

This library is heavily based on [em-ftpd](https://github.com/yob/em-ftpd), an FTPd
framework with similar design goals within the EventMachine ecosystem. It worked well
enough, but you know, callbacks and event loops make me something something.
