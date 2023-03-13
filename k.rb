require 'cbor-pure'             # part of "cbor-diag" gem
require 'base64'

def make_query_parameter(arr)
  enc = arr.map{ _1.to_cbor}.join
  Base64.urlsafe_encode64(enc, padding: false)
end

def print_query_parameter(arr)
  qp = make_query_parameter(arr)
  puts "#{arr.inspect} -> #{qp}"
end

print_query_parameter(["eth0"])
print_query_parameter(["myserver"])
# "Simpler" variant:
print_query_parameter([1533, "eth0"])
print_query_parameter([60002, "myserver"])


