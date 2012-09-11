module TentD
  module Model
    module UserScoped
      def self.included(base)
        base.class_eval do
          default_scope(:default).update(:user => nil)
          belongs_to :user, 'TentD::Model::User'
          before :valid? do
            self.user_id ||= User.current.id
          end
        end
      end
    end
  end
end
