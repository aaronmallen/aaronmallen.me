# frozen_string_literal: true

module Tasks
  module Operations
    class SyncIssues < Blog::Operation
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
        assigned, checked = step fetch(provider, client, known)
        fresh, held = assigned.partition { !known.key?(it[:id]) }

        [*held, *checked].each { follow(known.fetch(it[:id]), it, now) }
        fresh.each { import(provider, it, now) }.size
      end

      private

      def copy(issue)
        title, note = issue.values_at(:title, :body).map { it&.delete("\0") }

        { title: title&.match?(VISIBLE) ? title : issue.fetch(:reference), note: }
      end

      def discuss(source, issue)
        return unless listening?(source, issue)

        fresh = heard(issue)
        held = held(source, fresh.keys)

        fresh.each_value { keep(held[it[:remote_id]], source, it) }
        drop(held.except(*fresh.keys).values)
      end

      def drop(gone) = gone.empty? || task_comment_repo.delete_synced(gone.map(&:id))

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
          discuss(source, issue)
        end
      end

      def heard(issue) = issue.fetch(:comments).filter_map { said(it) }.to_h { [it[:remote_id], it] }

      def held(source, remote_ids)
        task_comment_repo.synced(source.task_id, source.provider, remote_ids).to_h { [it.remote_id, it] }
      end

      def import(provider, issue, now)
        transaction do
          task = task_repo.create(**copy(issue), list: EXTERNAL, position: task_repo.next_position)
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

      def listening?(source, issue) = issue.key?(:comments) && !task_repo.by_id(source.task_id).closed?

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

      def said(comment)
        body = comment[:body]&.delete("\0")
        return unless body&.match?(VISIBLE)

        { author: comment[:author], body:, created_at: comment[:created_at], remote_id: comment.fetch(:id),
          url: comment.fetch(:url) }
      end

      def settle(task, state, was, now)
        case state
        when OPEN then reopen(task, was)
        when STARTED then task.in_progress? || start_task.call(task.id)
        when COMPLETED then task.done? || complete_task.call(task.id, at: now)
        else task.closed? || cancel_task.call(task.id, at: now)
        end
      end

      def tags(issue)
        issue.fetch(:labels, Blog::Constants::EMPTY_ARRAY).filter_map { LABEL_TAG.call(it) { nil } }.uniq
      end

      def tracked(provider) = task_source_repo.still_there(provider).to_h { [it.remote_id, it] }
    end
  end
end
