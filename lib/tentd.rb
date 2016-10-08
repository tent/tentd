require 'tentd/version'
require 'tentd/utils'
require 'tent-client'

module TentD

  TENT_VERSION = '0.3'.freeze

  TentType = TentClient::TentType

  module REGEX
    VALID_ID = /\A[-0-9a-z_]+\Z/i
  end

  def self.settings
    @settings ||= {
      :debug => ENV['DEBUG'] == 'true'
    }
  end

  def self.logger
    return self.settings[:logger] if self.settings[:logger]

    require 'logger'
    self.settings[:logger] = Logger.new(STDOUT, STDERR)

    self.settings[:logger]
  end

  def self.setup!(options = {})
    setup_database!(options)

    require 'tentd/worker'
    require 'tentd/query'
    require 'tentd/feed'
    require 'tentd/refs'
    require 'tentd/proxied_post'
    require 'tentd/authorizer'
    require 'tentd/request_proxy_manager'
    require 'tentd/relationship_importer'
    require 'tentd/api'
  end

  def self.setup_database!(options = {})
    require 'sequel'
    require 'logger'

    if database_url = options[:database_url] || ENV['DATABASE_URL']
      @database = Sequel.connect(database_url, :logger => options[:database_logger] || Logger.new(ENV['DB_LOGFILE'] || STDOUT))
    end

    require 'tentd/query'
    require 'tentd/model'

    Model.soft_delete = ENV['SOFT_DELETE'].to_s != 'false'

    if (aws_access_key_id = options[:aws_access_key_id] || ENV['AWS_ACCESS_KEY_ID']) &&
       (aws_secret_access_key = options[:aws_secret_access_key] || ENV['AWS_SECRET_ACCESS_KEY'])
      # use S3 for attachments


      fog_adapter = {
        :provider => 'AWS',
        :aws_access_key_id => aws_access_key_id,
        :aws_secret_access_key => aws_secret_access_key
      }

      if aws_host = options[:aws_host] || ENV['AWS_HOST']
        fog_adapter[:host] = aws_host
      end

      if aws_port = options[:aws_port] || ENV['AWS_PORT']
        fog_adapter[:port] = aws_port
      end

      if aws_scheme = options[:aws_scheme] || ENV['AWS_SCHEME']
        fog_adapter[:scheme] = aws_scheme
      end

    elsif (google_storage_access_key_id = ENV['GOOGLE_STORAGE_ACCESS_KEY_ID']) &&
          (google_storage_secret_access_key = ENV['GOOGLE_STORAGE_SECRET_ACCESS_KEY'])

      fog_adapter = {
        :provider => 'Google',
        :google_storage_secret_access_key_id => google_storage_secret_access_key_id,
        :google_storage_secret_access_key => google_storage_secret_access_key
      }
    elsif (rackspace_username = ENV['RACKSPACE_USERNAME']) &&
          (rackspace_api_key = ENV['RACKSPACE_API_KEY'])

      fog_adapter = {
        :provider => 'Rackspace',
        :rackspace_username => rackspace_username,
        :rackspace_api_key => rackspace_api_key
      }

      if rackspace_auth_url = ENV['RACKSPACE_AUTH_URL']
        fog_adapter[:rackspace_auth_url] = rackspace_auth_url
      end
    elsif path = ENV['LOCAL_ATTACHMENTS_ROOT']
      fog_adapter = {
        :provider => 'Local',
        :local_root => path
      }
    else
      fog_adapter = nil
    end

    # force use of postgres for attachments
    if ENV['POSTGRES_ATTACHMENTS'].to_s == 'true'
      fog_adapter = nil
    end

    if fog_adapter
      require 'tentd/models/attachment/fog'

      Model::Attachment.fog_adapter = fog_adapter

      Model::Attachment.namespace = options[:attachments_namespace] || ENV['S3_BUCKET'] || ENV['ATTACHMENTS_NAMESPACE'] || 'tentd-attachments'
    else
      require 'tentd/models/attachment/sequel'
    end
  end

  def self.database
    @database
  end

end
