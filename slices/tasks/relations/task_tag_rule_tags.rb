# frozen_string_literal: true

module Tasks
  module Relations
    class TaskTagRuleTags < Blog::DB::Relation
      include Blog::DB::Taggings

      schema :task_tag_rule_tags, infer: true do
        associations do
          belongs_to :tag
          belongs_to :task_tag_rule
        end
      end

      def owner_key = :task_tag_rule_id
    end
  end
end
