# frozen_string_literal: true

module Tasks
  module Operations
    class SyncIssues < Blog::Operation
      CHECK_CLOSED_EVERY = 24 * 60 * 60
      CLOSED = %w[completed not_planned unassigned].map { Blog::Types::TaskSourceState[it] }.freeze
      COMMENT_FIELDS = %i[author body url].freeze
      COMPLETED = Blog::Types::TaskSourceState["completed"]
      EXTERNAL = Blog::Types::TaskList["external"]
      LABEL_TAG = Blog::Types::Normalized::LabelTag
      OPEN = Blog::Types::TaskSourceState["open"]
      STARTED = Blog::Types::TaskSourceState["started"]
      VISIBLE = /[[:^space:]]/

      include Deps[
        cancel_task: "operations.cancel_task",
        complete_task: "operations.complete_task",
        reopen_task: "operations.reopen_task",
        start_task: "operations.start_task",
        task_comment_repo: "repos.task_comment_repo",
        task_repo: "repos.task_repo",
        task_source_repo: "repos.task_source_repo",
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

      def discuss(source, task, issue)
        return unless listening?(task, issue)

        fresh = heard(issue)
        held = held(source, fresh.keys)

        fresh.each_value { keep(held[it[:remote_id]], source, it) }
        drop(held.except(*fresh.keys).values)
      end

      def drop(gone) = gone.empty? || task_comment_repo.delete_synced(gone.map(&:id))

      def due?(source, now)
        !CLOSED.include?(source.remote_state) || source.checked_at.nil? || source.checked_at <= now - CHECK_CLOSED_EVERY
      end

      def fetch(provider, client, known, now)
        return Failure(:not_configured) unless client.configured?

        assigned = client.assigned_issues.items

        Success([assigned, client.issues(unseen(known, assigned, now))])
      rescue Record::RateLimited
        Failure(:rate_limited)
      rescue Record::Error => e
        Failure([:"#{provider}_failed", e.message])
      end

      def follow(source, issue, now)
        state = issue.fetch(:remote_state)
        task = task_repo.by_id(source.task_id)

        transaction do
          task = settle(task, state, source.remote_state, now) unless state == source.remote_state
          rewrite(task, issue)
          restamp(source, state, issue[:url], now)
          discuss(source, task, issue)
        end
      end

      def heard(issue) = issue.fetch(:comments).filter_map { said(it) }.to_h { [it[:remote_id], it] }

      def held(source, remote_ids)
        task_comment_repo.synced(source.task_id, source.provider, remote_ids).to_h { [it.remote_id, it] }
      end

      def import(provider, issue, now)
        transaction do
          task = task_repo.append(**copy(issue), list: EXTERNAL)
          task_repo.add_tags(task.id, tags(issue))
          source = { task_id: task.id, provider:, remote_id: issue[:id], url: issue[:url], remote_state: OPEN }
          follow(task_source_repo.create(**source), issue, now)
        end
      end

      def keep(held, source, comment)
        return task_comment_repo.create(**comment, task_id: source.task_id, provider: source.provider) unless held

        changes = { **comment.slice(*COMMENT_FIELDS), task_id: source.task_id }
        task_comment_repo.update(held.id, **changes) unless changes == held.to_h.slice(*changes.keys)
      end

      def listening?(task, issue) = issue.key?(:comments) && !task.closed?

      def reopen(task, was)
        return Success(task) unless task.closed? || (was == STARTED && task.in_progress?)

        reopen_task.call(task.id)
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

      def said(comment)
        body = comment[:body]&.delete("\0")
        return unless body&.match?(VISIBLE)

        { author: comment[:author], body:, created_at: comment[:created_at], remote_id: comment.fetch(:id),
          url: comment.fetch(:url) }
      end

      def settle(task, state, was, now)
        case state
        when OPEN then reopen(task, was)
        when STARTED then task.in_progress? ? Success(task) : start_task.call(task.id)
        when COMPLETED then task.done? ? Success(task) : complete_task.call(task.id, at: now)
        else close(task, now)
        end.value_or(task)
      end

      def tags(issue)
        issue.fetch(:labels, Blog::Constants::EMPTY_ARRAY).filter_map { LABEL_TAG.call(it) { nil } }.uniq
      end

      def tracked(provider) = task_source_repo.still_there(provider).to_h { [it.remote_id, it] }

      def unseen(known, assigned, now)
        known.except(*assigned.map { it[:id] }).values.select { due?(it, now) }.to_h { [it.remote_id, it.url] }
      end
    end
  end
end
