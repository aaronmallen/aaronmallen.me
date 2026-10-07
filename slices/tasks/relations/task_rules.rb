# frozen_string_literal: true

module Tasks
  module Relations
    class TaskRules < Blog::DB::Relation
      schema :task_rules, infer: true do
        associations do
          has_many :task_rule_tags
          has_many :tags, through: :task_rule_tags, view: :in_name_order
          has_many :task_rule_projects
          has_many :projects, through: :task_rule_projects, view: :in_name_order
        end
      end
    end
  end
end
