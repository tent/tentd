ApiValidator.format_validators['https://tent.io/formats/authorize-type-uri'] = lambda do |value|
  return true if value == 'all'
  begin
    uri = URI(actual)
    uri.scheme && uri.host
  rescue URI::InvalidURIError, ArgumentError
    false
  end
end
