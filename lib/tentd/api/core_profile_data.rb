require 'hashie'

module TentD
  class API
    class CoreProfileData < Hashie::Mash
      def expected_version
        v = TentVersion.from_uri(Model::ProfileInfo::TENT_PROFILE_TYPE_URI)
        v.parts = v.parts[0..-2] << 'x'
        v
      end

      def versions
        keys.select { |key|
          key =~ %r|^#{Model::ProfileInfo::TENT_PROFILE_TYPE_URI.sub(/\/v.*?$/, '')}|
        }.map { |key| TentVersion.from_uri(key) }.sort
      end

      def version
        versions.find do |v|
          v == expected_version
        end
      end

      def version_key
        Model::ProfileInfo::TENT_PROFILE_TYPE_URI.sub(%r|/v.*?$|, '/v' << version.to_s)
      end

      def entity?(entity)
        self[version_key][:entity] == entity
      end

      def servers
        self[version_key][:servers]
      end
    end
  end
end
