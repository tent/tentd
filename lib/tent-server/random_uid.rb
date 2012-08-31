module TentServer
  module RandomUid
    def random_uid
      rand(36 ** 8 ).to_s(36)
    end
  end
end
