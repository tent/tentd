def expect_pagination_header(response, options)
  link_headers = response.headers['Link'].to_s.split(/,\s*/).inject({}) do |memo, link|
    url, rel = parse_link_header(link)
    next unless url && rel
    memo[rel] = {
      :params => parse_params(url),
      :uri => URI(url)
    }
    memo
  end

  if next_params = options[:next]
    expect(link_headers['next']).to_not be_nil, "Expected next pagination header, but it was not there"
    expect(link_headers['next'][:uri].path).to eql(options[:path])
    next_params.each_pair do |key, val|
      actual = link_headers['next'][:params][key.to_s]
      expect(actual).to eql(val), "Expected '#{key}' param to eql #{val.inspect} in next pagination header, got #{actual.inspect} instead\n#{link_headers['next'][:params].inspect}"
    end
  else
    expect(link_headers['next']).to be_nil, "Expected absense of next pagination header, but got #{link_headers['next'].inspect}"
  end

  if prev_params = options[:prev]
    expect(link_headers['prev']).to_not be_nil, "Expected prev pagination header, but it was not there"
    expect(link_headers['prev'][:uri].path).to eql(options[:path])
    prev_params.each_pair do |key, val|
      actual = link_headers['prev'][:params][key.to_s]
      expect(actual).to eql(val), "Expected '#{key}' param to eql #{val.inspect} in prev pagination header, got #{actual.inspect} instead\n#{link_headers['prev'][:params].inspect}"
    end
  else
    expect(link_headers['prev']).to be_nil, "Expected absense of prev pagination header, but got #{link_headers['prev'].inspect}"
  end
end

def parse_link_header(link)
  return unless link.match(%r{<([^>]+)>;\s*rel=['"]([^'"]+)['"]})
  url, rel = $1, $2
  [url, rel]
end

def parse_params(url)
  uri = URI(url)
  params = uri.query.split('&').inject({}) do |memo, param|
    key, val = param.split('=')
    memo[key] = URI.decode_www_form_component(val)
    memo
  end
end
