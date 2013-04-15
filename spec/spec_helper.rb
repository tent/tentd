$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

ENV['RACK_ENV'] ||= 'test'

require 'bundler/setup'
require 'mocha/api'
require 'webmock/rspec'
require 'rack/test'

require 'tentd'

ENV['TENT_ENTITY'] ||= 'http://example.org'

ENV['DB_LOGFILE'] ||= '/dev/null'
TentD.setup!(:database_url => ENV['TEST_DATABASE_URL'])

RSpec.configure do |config|
  config.include Rack::Test::Methods

  config.color = true

  config.mock_with :mocha
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    TentD.database.from(*TentD.database.tables).truncate

    # create user / meta post
    TentD::Model::User.first_or_create(ENV['TENT_ENTITY'])
  end

  config.before(:each) do |example|
    example.class.class_eval do
      let(:current_user) { TentD::Model::User.first_or_create(ENV['TENT_ENTITY']) }

      let(:server_entity) { server_url }
      let(:server_url) { "http://example.tent.local" }
      let(:server_meta) do
        TentD::Utils::Hash.stringify_keys(current_user.meta_post.as_json[:content])
      end
      let(:client) do
        TentClient.new(
          server_meta["entity"],
          :server_meta => server_meta,
          :faraday_adapter => [:rack, lambda { |env|
            current_session.request(env['PATH_INFO'], env)
          }]
        )
      end
    end
  end
end
