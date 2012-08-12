require 'grape'

module SP
  module Server
    class API < Grape::API
      version 'v1', using: :header

      resource :subscriptions do
        post do
          puts params[:foo]
        end
      end
    end
  end
end
