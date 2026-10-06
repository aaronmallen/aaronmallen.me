# frozen_string_literal: true

module Tasks
  module Operations
    class SyncIssues < Blog::Operation
      CLOSED = Structs::TaskSource::CLOSED
      COMPLETED = Blog::Types::TaskSourceState["completed"]
      EXTERNAL = Blog::Types::TaskList["external"]
      LABEL_TAG = Blog::Types::Normalized::LabelTag
      OPEN = Blog::Types::TaskSourceState["open"]
      STARTED = Blog::Types::TaskSourceState["started"]
      VISIBLE = SyncComments::VISIBLE

      include Deps[
        cancel_task: "operations.cancel_task",
        complete_task: "operations.complete_task",
        reopen_task: "operations.reopen_task",
        start_task: "operations.start_task",
        sync_comments: "operations.sync_comments",
        task_event_repo: "repos.task_event_repo",
        task_repo: "repos.task_repo",
        task_source_repo: "repos.task_source_repo",
        task_tag_rule_repo: "repos.task_tag_rule_repo",
      ]

      def call(provider:, client:, now: Time.now)
        known = tracked(provider)
        assigned, checked = step fetch(provider, client, known, now)
        fresh, held = assigned.partition { !known.key?(it[:id]) }

        [*held, *checked].each { follow(known.fetch(it[:id]), it, now) }
        fresh.each { import(provider, it, now) }.size
      end

      private

      def close(task, now) = task.closed? ? Success(task) : cancel_task.call(task.id, at: now)

      def copy(issue)
        title, note = issue.values_at(:title, :body).map { it&.delete("\0") }

        { title: title&.match?(VISIBLE) ? title : issue.fetch(:reference), note: }
      end

      def fetch(provider, client, known, now)
        return Failure(:not_configured) unless client.configured?

        assigned = client.assigned_issues

        Success([assigned, client.issues(unseen(known, assigned, now))])
      rescue Record::RateLimited
        Failure(:rate_limited)
      rescue Record::Error => e
        Failure([:"#{provider}_failed", e.message])
      end

      def finish(task, now) = reopen(task, nil, now).bind { complete_task.call(task.id, at: now) }

      def follow(source, issue, now)
        state = issue.fetch(:remote_state)
        task = task_repo.by_id(source.task_id)
        return unless task

        transaction do
          task = settle(task, state, source.remote_state, now) unless state == source.remote_state
          rewrite(task, issue)
          restamp(source, state, issue[:url], now)
          sync_comments.call(source, task, issue)
        end
      end

      def import(provider, issue, now)
        transaction do
          task = task_repo.append(**copy(issue), list: EXTERNAL)
          label(task, tags(provider, issue), now)
          source = { task_id: task.id, provider:, remote_id: issue[:id], url: issue[:url], remote_state: OPEN }
          follow(task_source_repo.create(**source), issue, now)
        end
      end

      def label(task, names, now) = task_event_repo.track(task.id, now) { task_repo.add_tags(task.id, names) }

      def reopen(task, was, now)
        return Success(task) unless task.closed? || (was == STARTED && task.in_progress?)

        reopen_task.call(task.id, at: now)
      end

      def restamp(source, state, url, now)
        checked_at = now if CLOSED.include?(state)
        return if [source.remote_state, source.url, source.checked_at] == [state, url, checked_at]

        task_source_repo.update(source.id, remote_state: state, url:, checked_at:)
      end

      def rewrite(task, issue)
        return unless issue.key?(:title)

        fields = copy(issue)
        task_repo.update(task.id, **fields) unless fields == { title: task.title, note: task.note }
      end

      def settle(task, state, was, now)
        case state
        when OPEN then reopen(task, was, now)
        when STARTED then task.in_progress? ? Success(task) : start_task.call(task.id, at: now, seen: false)
        when COMPLETED then task.done? ? Success(task) : finish(task, now)
        else close(task, now)
        end.value_or(task)
      end

      def tags(provider, issue)
        labeled = issue.fetch(:labels, Blog::Constants::EMPTY_ARRAY).filter_map { LABEL_TAG.call(it) { nil } }

        [*labeled, *task_tag_rule_repo.tag_names_for(provider, issue[:origin])].uniq
      end

      def tracked(provider) = task_source_repo.for_provider(provider).to_h { [it.remote_id, it] }

      def unseen(known, assigned, now)
        known.except(*assigned.map { it[:id] }).values.select { it.due?(now) }.to_h { [it.remote_id, it.url] }
      end
    end
  end
end
