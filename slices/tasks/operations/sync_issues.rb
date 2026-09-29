# frozen_string_literal: true

module Tasks
  module Operations
    class SyncIssues < Blog::Operation
      COMPLETED = Blog::Types::TaskSourceState["completed"]
      EXTERNAL = Blog::Types::TaskList["external"]
      OPEN = Blog::Types::TaskSourceState["open"]
      STARTED = Blog::Types::TaskSourceState["started"]

      include Deps[
        cancel_task: "operations.cancel_task",
        complete_task: "operations.complete_task",
        reopen_task: "operations.reopen_task",
        start_task: "operations.start_task",
        task_repo: "repos.task_repo",
        task_source_repo: "repos.task_source_repo",
      ]

      def call(provider:, client:, now: Time.now)
        known = tracked(provider)
        assigned, checked = step fetch(provider, client, known)
        fresh, held = assigned.partition { !known.key?(it[:id]) }

        [*held, *checked].each { follow(known.fetch(it[:id]), it, now) }
        fresh.each { import(provider, it, now) }.size
      end

      private

      def copy(issue) = { title: issue[:title], note: issue[:body] }.transform_values { it&.delete("\0") }

      def fetch(provider, client, known)
        return Failure(:not_configured) unless client.configured?

        assigned = client.assigned_issues.items
        unseen = known.except(*assigned.map { it[:id] }).transform_values(&:url)

        Success([assigned, client.issues(unseen)])
      rescue Record::RateLimited
        Failure(:rate_limited)
      rescue Record::Error => e
        Failure([:"#{provider}_failed", e.message])
      end

      def follow(source, issue, now)
        state = issue.fetch(:remote_state)
        task = task_repo.by_id(source.task_id)

        transaction do
          settle(task, state, source.remote_state, now) unless state == source.remote_state
          rewrite(task, issue)
          restamp(source, state, issue[:url])
        end
      end

      def import(provider, issue, now)
        transaction do
          task = task_repo.create(**copy(issue), list: EXTERNAL, position: task_repo.next_position)
          source = { task_id: task.id, provider:, remote_id: issue[:id], url: issue[:url], remote_state: OPEN }
          follow(task_source_repo.create(**source), issue, now)
        end
      end

      def reopen(task, was)
        return unless task.closed? || (was == STARTED && task.in_progress?)

        reopen_task.call(task.id)
      end

      def restamp(source, state, url)
        return if source.remote_state == state && source.url == url

        task_source_repo.update(source.id, remote_state: state, url:)
      end

      def rewrite(task, issue)
        return unless issue.key?(:title)

        fields = copy(issue)
        task_repo.update(task.id, **fields) unless fields == { title: task.title, note: task.note }
      end

      def settle(task, state, was, now)
        case state
        when OPEN then reopen(task, was)
        when STARTED then task.in_progress? || start_task.call(task.id)
        when COMPLETED then task.done? || complete_task.call(task.id, at: now)
        else task.closed? || cancel_task.call(task.id, at: now)
        end
      end

      def tracked(provider) = task_source_repo.still_there(provider).to_h { [it.remote_id, it] }
    end
  end
end
