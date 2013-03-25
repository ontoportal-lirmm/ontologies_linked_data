# This is a test rack app for use with the linked data serializer tests

use LinkedData::Security::Authorization

map '/' do
  run Proc.new { |env| [200, {'Content-Type' => 'text/html'}, ['success']] }
end