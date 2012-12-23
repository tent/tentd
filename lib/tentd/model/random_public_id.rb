require 'securerandom'

module TentD
  module Model
    module RandomPublicId
      def random_id
        SecureRandom.urlsafe_base64(16)
      end
    end
  end
end
