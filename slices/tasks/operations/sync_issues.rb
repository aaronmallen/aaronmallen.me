# frozen_string_literal: true

module Tasks
  module Operations
    class SyncIssues < Blog::Operation
      COMPLETED = Blog::Types::TaskSourceState["completed"]
      EXTERNAL = Blog::Types::TaskList["external"]
      GITHUB = Blog::Types::TaskSourceProvider["github"]
      OPEN = Blog::Types::TaskSourceState["open"]
      UNASSIGNED = Blog::Types::TaskSourceState["unassigned"]

      include Deps[
        cancel_task: "operations.cancel_task",
        client: "record.github.client",
        complete_task: "operations.complete_task",
        reopen_task: "operations.reopen_task",
        task_repo: "repos.task_repo",
        task_source_repo: "repos.task_source_repo",
      ]

      def call(now: Time.now)
        known = tracked
        assigned, checked = step fetch(known)
        fresh, held = assigned.partition { !known.key?(it[:id]) }

        [*held, *checked].each { follow(known.fetch(it[:id]), it, now) }
        fresh.each { import(it) }.size
      end

      private

      def copy(issue) = { title: issue[:title], note: issue[:body] }.transform_values { it&.delete("\0") }

      def fetch(known)
        return Failure(:not_configured) unless client.configured?

        assigned = client.assigned_issues.items
        unseen = known.except(*assigned.map { it[:id] }).transform_values(&:url)

        Success([assigned, client.issues(unseen)])
      rescue Record::GitHub::Client::RateLimited
        Failure(:rate_limited)
      rescue Record::GitHub::Client::Error => e
        Failure([:github_failed, e.message])
      end

      def follow(source, issue, now)
        state = state_of(issue)
        task = task_repo.by_id(source.task_id)

        transaction do
          settle(task, state, now) unless state == source.remote_state
          rewrite(task, issue)
          restamp(source, state, issue[:url])
        end
      end

      def import(issue)
        transaction do
          task = task_repo.create(**copy(issue), list: EXTERNAL, position: task_repo.next_position)
          task_source_repo.create(task_id: task.id, provider: GITHUB, remote_id: issue[:id], url: issue[:url],
                                  remote_state: OPEN)
        end
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

      def settle(task, state, now)
        case state
        when OPEN then task.closed? && reopen_task.call(task.id)
        when COMPLETED then task.done? || complete_task.call(task.id, at: now)
        else task.closed? || cancel_task.call(task.id, at: now)
        end
      end

      def state_of(issue)
        case issue
        in { state: :moved | :deleted => gone } then Blog::Types::TaskSourceState[gone.to_s]
        in { assigned: false } then UNASSIGNED
        in { state: :closed, reason: } then Blog::Types::TaskSourceState[reason.to_s]
        else OPEN
        end
      end

      def tracked = task_source_repo.still_there(GITHUB).to_h { [it.remote_id, it] }
    end
  end
end
