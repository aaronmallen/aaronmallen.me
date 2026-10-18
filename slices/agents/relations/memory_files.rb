# frozen_string_literal: true

module Agents
  module Relations
    class MemoryFiles < Blog::DB::Relation
      schema :memory_files, infer: true do
        associations do
          has_many :memory_facts, view: :live_in_order
        end
      end

      def in_load_order = order(self[:scope].asc, self[:path].asc, self[:id].asc)

      def linkable = linkables(title: :path, day: self.class.site_day(:created_at))

      def loading(repo:, project_ids:, task_ids:)
        where(
          Sequel.|(
            { scope: "global" }, { scope: "repo", repo: }, { scope: "project", project_id: project_ids },
            { scope: "task", task_id: task_ids },
          ),
        )
      end

      def matching(text) = containing(text, :path)
    end
  end
end
