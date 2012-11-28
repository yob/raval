# coding: binary

require 'ftpd'
require 'fake'

FTPD::Server.supervise("127.0.0.1","3000", FakeFTPDriver)

while true
  sleep 5
end
