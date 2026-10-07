# frozen_string_literal: true

module Tasks
  module Relations
    class Projects < Blog::DB::Relation
      schema :projects, infer: true

      def in_name_order = order(self[:name].asc, self[:id].asc)
    end
  end
end
