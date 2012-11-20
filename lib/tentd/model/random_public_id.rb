module TentD
  module Model
    module RandomPublicId
      def random_id
        rand(36 ** 6).to_s(36)
      end
    end
  end
end
