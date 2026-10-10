# frozen_string_literal: true

module Tasks
  module Operations
    class SyncIssues < Blog::Operation
      include Record::Remote

      CLOSED = Blog::Types::ClosedTaskSourceState
      EMPTY_ARRAY = Blog::Constants::EMPTY_ARRAY
      EMPTY_HASH = Blog::Constants::EMPTY_HASH
      EXTERNAL = Blog::Types::TaskList["external"]
      LABEL_TAG = Blog::Types::Normalized::LabelTag
      OPEN = Blog::Types::TaskSourceState["open"]
      UNASSIGNED = Blog::Types::TaskSourceState["unassigned"]
      VISIBLE = SyncComments::VISIBLE

      include Deps[
        reach_issues: "operations.reach_issues",
        settle_task: "operations.settle_task",
        sync_comments: "operations.sync_comments",
        sync_links: "operations.sync_links",
        task_event_mutations: "repos.task_event_mutations",
        task_link_queries: "repos.task_link_queries",
        task_mutations: "repos.task_mutations",
        task_queries: "repos.task_queries",
        task_source_mutations: "repos.task_source_mutations",
        task_source_queries: "repos.task_source_queries",
        task_rule_mutations: "repos.task_rule_mutations",
        task_rule_queries: "repos.task_rule_queries",
      ]

      def call(provider:, client:, now: Time.now)
        known = tracked(provider)
        assigned, checked, history = step fetch(provider, client, known, now)
        held, fresh = assigned.partition { known.key?(it[:id]) }

        follow_all([*held, *checked], known, history, now)
        import_all(provider, fresh, known, now)

        fresh.size + step(relate(provider, client, known, now, [assigned, checked])).size
      end

      private

      def copy(issue)
        title, note = issue.values_at(:title, :body).map { it&.delete("\0") }

        { title: title&.match?(VISIBLE) ? title : issue.fetch(:reference), note: }
      end

      def fetch(provider, client, known, now)
        remote(client, provider) do
          assigned = client.assigned_issues
          checked = client.issues(unseen(known, assigned, now))

          Success([assigned, checked, history(client, [*assigned, *checked], known)])
        end
      end

      def follow(source, issue, now, history: EMPTY_HASH, reached: false)
        task = task_queries.by_id(source.task_id)
        return unless task

        state = observed(task, source, issue.fetch(:remote_state), reached)
        changes = history[issue[:id]]

        transaction do
          task = settle_task.call(task, from: source.remote_state, to: state, at: now, history: changes).value!
          rewrite(task, issue)
          restamp(source, state, issue, changes, now)
          sync_comments.call(source, task, issue)
        end
      end

      def follow_all(issues, known, history, now)
        issues.each { follow(known.fetch(it[:id]), it, now, history:) }
      end

      def history(client, issues, known)
        return EMPTY_HASH unless client.respond_to?(:transitions)

        client.transitions(issues, known.transform_values(&:history_cursor).compact)
      end

      def import(provider, issue, now, reached: false)
        transaction do
          task = task_mutations.append(**copy(issue), list: EXTERNAL)
          label(task, provider, issue, now)
          fields = { task_id: task.id, provider:, remote_id: issue[:id], url: issue[:url], remote_state: OPEN }
          task_source_mutations.create(**fields).tap { follow(it, issue, now, reached:) }
        end
      end

      def import_all(provider, issues, known, now, reached: false)
        issues.each { known[it[:id]] = import(provider, it, now, reached:) }
      end

      def label(task, provider, issue, now)
        names, project_ids = task_rule_queries.targets(provider, issue[:origin])
        labeled = issue.fetch(:labels, EMPTY_ARRAY).filter_map { LABEL_TAG.call(it) { nil } }
        task_event_mutations.track(task.id, now) { task_mutations.add_tags(task.id, [*labeled, *names].uniq) }
        task_rule_mutations.link_projects([task.id], project_ids)
      end

      def observed(task, source, state, reached)
        return source.remote_state if source.remote_state == UNASSIGNED && CLOSED.valid?(state)
        return state unless state == UNASSIGNED && !task.closed?

        reached || task_link_queries.synced?(task.id) ? OPEN : state
      end

      def reach(provider, client, assigned, known)
        remote(client, provider) { Success(reach_issues.call(client, assigned, known)) }
      end

      def relate(provider, client, known, now, (assigned, checked))
        reached = reach(provider, client, assigned, known).fmap { import_all(provider, it, known, now, reached: true) }
        sync_links.call(known, [*assigned, *checked, *reached.value_or(EMPTY_ARRAY)])
        reached
      end

      def restamp(source, state, issue, changes, now)
        checked_at = now if CLOSED.valid?(state)
        history_cursor = source.next_cursor(issue[:updated_at], changes, now)
        fields = { remote_state: state, url: issue[:url], checked_at:, history_cursor: }
        return if fields.all? { |name, value| source[name] == value }

        task_source_mutations.update(source.id, **fields)
      end

      def rewrite(task, issue)
        return unless issue.key?(:title)

        fields = copy(issue)
        task_mutations.update(task.id, **fields) unless fields == { title: task.title, note: task.note }
      end

      def tracked(provider) = task_source_queries.for_provider(provider).to_h { [it.remote_id, it] }

      def unseen(known, assigned, now)
        known.except(*assigned.map { it[:id] }).values.select { it.due?(now) }.to_h { [it.remote_id, it.url] }
      end
    end
  end
end
