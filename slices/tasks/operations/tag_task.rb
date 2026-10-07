# frozen_string_literal: true

module Tasks
  module Operations
    class TagTask < Operation
      include Deps[
        task_event_repo: "repos.task_event_repo",
        task_repo: "repos.task_repo",
        task_tag_repo: "repos.task_tag_repo",
      ]

      def call(id, name, at: Time.now)
        step find(id)

        task_event_repo.track(id, at) { task_tag_repo.add(id, name) }
        task_repo.by_id(id)
      end

      private

      def find(id) = found(task_repo.exist?(id) && id)
    end
  end
end
