require 'hawk'

module TentD
  module Utils

    MAC_ALGORITHM = "sha256".freeze

    def self.random_id
      SecureRandom.urlsafe_base64(16)
    end

    def self.hawk_key
      SecureRandom.hex(32)
    end

    def self.hawk_algorithm
      MAC_ALGORITHM
    end

    def self.hex_digest(io)
      io = StringIO.new(io) if String === io

      digest = Digest::SHA512.new
      while buffer = io.read(1024)
        digest << buffer
      end
      io.rewind
      "sha512t256-" + digest.hexdigest[0...64]
    end

    def self.timestamp
      (Time.now.to_f * 1000).to_i
    end

    def self.expand_uri_template(template, params = {})
      template.to_s.gsub(/{([^}]+)}/) { URI.encode_www_form_component(params[$1] || params[$1.to_sym]) }
    end

    def self.sign_url(credentials, url, options = {})
      credentials = Hash.symbolize_keys(credentials)

      options[:ttl] ||= 86400 # 24 hours
      options[:method] ||= 'GET'

      uri = URI(url)
      options.merge!(
        :credentials => {
          :id => credentials[:id],
          :key => credentials[:hawk_key],
          :algorithm => credentials[:hawk_algorithm]
        },
        :host => uri.host,
        :port => uri.port || (uri.scheme == 'https' ? 443 : 80),
        :request_uri => uri.path + (uri.query ? "?#{uri.query}" : '')
      )

      bewit = Hawk::Crypto.bewit(options)
      uri.query ? uri.query += "&bewit=#{bewit}" : uri.query = "bewit=#{bewit}"
      uri.to_s
    end

    module Hash
      extend self

      def deep_dup(item)
        case item
        when ::Hash
          item.inject({}) do |memo, (k,v)|
            memo[k] = deep_dup(v)
            memo
          end
        when Array
          item.map { |i| deep_dup(i) }
        when Symbol, TrueClass, FalseClass, NilClass, Numeric
          item
        else
          item.respond_to?(:dup) ? item.dup : item
        end
      end

      def deep_merge!(hash, *others)
        others.each do |other|
          other.each_pair do |key, val|
            if hash.has_key?(key)
              next if hash[key] == val
              case val
              when ::Hash
                Utils::Hash.deep_merge!(hash[key], val)
              when Array
                hash[key].concat(val)
              when FalseClass
                # false always wins
                hash[key] = val
              end
            else
              hash[key] = val
            end
          end
        end
      end

      def slice(hash, *keys)
        keys.each_with_object(hash.class.new) { |k, new_hash|
          new_hash[k] = hash[k] if hash.has_key?(k)
        }
      end

      def slice!(hash, *keys)
        hash.replace(slice(hash, *keys))
      end

      def stringify_keys(hash, options = {})
        transform_keys(hash, :to_s, options).first
      end

      def stringify_keys!(hash, options = {})
        hash.replace(stringify_keys(hash, options))
      end

      def symbolize_keys(hash, options = {})
        transform_keys(hash, :to_sym, options).first
      end

      def symbolize_keys!(hash, options = {})
        hash.replace(symbolize_keys(hash, options))
      end

      def transform_keys(*items, method, options)
        items.map do |item|
          case item
          when ::Hash
            item.inject(::Hash.new) do |new_hash, (k,v)|
              new_hash[k.send(method)] = (options[:deep] != false) ? transform_keys(v, method, options).first : v
              new_hash
            end
          when ::Array
            item.map { |i| transform_keys(i, method, options).first }
          else
            item
          end
        end
      end
    end

  end
end
