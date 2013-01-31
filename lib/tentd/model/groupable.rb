module TentD
  module Model
    module Groupable
      def assign_groups(groups)
        return unless groups.to_a.any?

        self.groups = groups.select { |group|
          Group.where(:user_id => user_id, :public_id => group[:id]).any?
        }.map { |group| group[:id] }
        save
      end
    end
  end
end
