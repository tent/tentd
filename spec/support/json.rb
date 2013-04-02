require 'yajl'

def encode_json(data)
  Yajl::Encoder.encode(data)
end

def parse_json(data)
  Yajl::Parser.parse(data)
end
