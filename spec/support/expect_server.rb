def expect_server(env, url)
  expect(env[:url].to_s).to match(url)
end
