require 'openssl'
require 'base64'

module TentD
  class API
    class AuthenticationVerification < Middleware
      def action(env)
        if env.hmac? && !(env.hmac.verified = verify_signature(env))
          env = [403, {}, ['Invalid MAC Signature']]
        end
        env
      end

      private

      # constant-time comparison algorithm to prevent timing attacks
      def secure_compare(a, b)
        return false unless a.bytesize == b.bytesize

        l = a.unpack "C#{a.bytesize}"

        res = 0
        b.each_byte { |byte| res |= byte ^ l.shift }
        res == 0
      end

      def verify_signature(env)
        secure_compare(env.hmac.mac, build_request_signature(env))
      end

      def build_request_signature(env)
        time = env.hmac.ts.to_i
        nonce = env.hmac.nonce
        request_string = build_request_string(time, nonce, env)
        signature = Base64.encode64(OpenSSL::HMAC.digest(openssl_digest(env.hmac.algorithm).new, env.hmac.secret, request_string)).sub("\n", '')
      end

      def build_request_string(time, nonce, env)
        body = env['rack.input'].read
        env['rack.input'].rewind
        request_uri = env.SCRIPT_NAME + (env.QUERY_STRING != '' ? "?#{env.QUERY_STRING}" : '')
        [time.to_s, nonce, env.REQUEST_METHOD.to_s.upcase, request_uri, env.HTTP_HOST.split(':').first, env.SERVER_PORT, body, nil].join("\n")
      end

      def openssl_digest(mac_algorithm)
        @openssl_digest ||= OpenSSL::Digest.const_get(mac_algorithm.to_s.gsub(/hmac|-/, '').upcase)
      end
    end
  end
end
