# frozen_string_literal: true

module Tasks
  module Relations
    class TaskTagRules < Blog::DB::Relation
      schema :task_tag_rules, infer: true do
        associations do
          has_many :task_tag_rule_tags
          has_many :tags, through: :task_tag_rule_tags, view: :in_name_order
        end
      end
    end
  end
end
