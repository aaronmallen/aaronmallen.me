# frozen_string_literal: true

module Tasks
  module Repos
    class TaskCountQueries < Blog::DB::Repo
      COMPLETED = Blog::Types::TaskTab["completed"]
      TODAY = Blog::Types::TaskTab["today"]

      include Deps[task_label_queries: "repos.task_label_queries"]

      def on_tab(tab, sprint:, **search)
        found = case tab
                  when COMPLETED then tasks.closed
                  when TODAY then tasks.for_sprint(sprint.id).open
                  else tasks.in_list(tab).open
                end

        found.searched(**task_label_queries.terms(**search)).count
      end
    end
  end
end
