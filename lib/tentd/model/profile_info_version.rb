require 'hashie'

module TentD
  module Model
    class ProfileInfoVersion < Sequel::Model(:profile_info_versions)
      include TypeProperties

      plugin :paranoia
      plugin :serialization
      serialize_attributes :json, :content

      def before_create
        self.created_at = Time.now
        super
      end

      def before_save
        self.updated_at = Time.now
        super
      end
    end
  end
end
