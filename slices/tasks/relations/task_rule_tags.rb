# frozen_string_literal: true

module Tasks
  module Relations
    class TaskRuleTags < Blog::DB::Relation
      include Blog::DB::Taggings

      schema :task_rule_tags, infer: true do
        associations do
          belongs_to :tag
          belongs_to :task_rule
        end
      end

      def owner_key = :task_rule_id
    end
  end
end
