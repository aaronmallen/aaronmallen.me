# frozen_string_literal: true

module Tasks
  module Operations
    class SyncIssues < Blog::Operation
      include Issues::Remote

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
        run = Structs::IssueSyncRun.new(provider:, client:, now:, known: tracked(provider))
        listing, checked, history = step fetch(run)
        count = settle(run, listing.items, checked, history)

        listing.cut_short? ? step(Failure(:page_limit)) : count
      end

      private

      def copy(issue)
        title, note = issue.values_at(:title, :body).map { it&.delete("\0") }

        { title: title&.match?(VISIBLE) ? title : issue.fetch(:reference), note: }
      end

      def fetch(run)
        remote(run.client, run.provider) do
          listing = run.client.assigned_issues
          assigned = listing.items.uniq { it[:id] }
          checked = run.client.issues(unseen(run, assigned))

          Success([listing.with(items: assigned), checked, history(run, [*assigned, *checked])])
        end
      end

      def follow(run, source, task, issue, history: EMPTY_HASH, reached: false)
        state = observed(task, source, issue.fetch(:remote_state), reached)
        changes = history[issue[:id]]

        transaction do
          task = settle_task.call(task, from: source.remote_state, to: state, at: run.now, history: changes).value!
          rewrite(task, issue)
          restamp(source, state, issue, changes, run.now)
          sync_comments.call(source, task, issue)
        end
      end

      def follow_all(run, issues, history)
        sources = issues.map { run.known.fetch(it[:id]) }
        tasks = task_queries.detailed_in_order(sources.map(&:task_id))

        issues.zip(sources, tasks) { |issue, source, task| task && follow(run, source, task, issue, history:) }
      end

      def history(run, issues)
        return EMPTY_HASH unless run.client.respond_to?(:transitions)

        run.client.transitions(issues, run.known.transform_values(&:history_cursor).compact)
      end

      def import(run, issue, reached: false)
        transaction do
          task = task_mutations.append(**copy(issue), list: EXTERNAL)
          label(task, run.provider, issue, run.now)
          fields = { task_id: task.id, remote_id: issue[:id], url: issue[:url], remote_state: OPEN }
          task_source_mutations.create(**fields, provider: run.provider).tap { follow(run, it, task, issue, reached:) }
        end
      end

      def import_all(run, issues, reached: false)
        issues.each { run.track(import(run, it, reached:)) }
      end

      def label(task, provider, issue, now)
        names, project_ids = task_rule_queries.targets(provider, issue[:origin])
        labeled = issue.fetch(:labels, EMPTY_ARRAY).filter_map { LABEL_TAG.call(it) { nil } }
        task_event_mutations.track(task.id, now) { task_mutations.add_tags(task.id, [*labeled, *names].uniq) }
        task_rule_mutations.fill_project([task.id], project_ids.first)
      end

      def observed(task, source, state, reached)
        return source.remote_state if source.remote_state == UNASSIGNED && CLOSED.valid?(state)
        return state unless state == UNASSIGNED && !task.closed?

        reached || task_link_queries.synced?(task.id) ? OPEN : state
      end

      def reach(run, assigned)
        remote(run.client, run.provider) { Success(reach_issues.call(run.client, assigned, run.known)) }
      end

      def relate(run, assigned:, checked:)
        reached = reach(run, assigned).fmap { import_all(run, it, reached: true) }
        sync_links.call(run.known, [*assigned, *checked, *reached.value_or(EMPTY_ARRAY)])
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

      def settle(run, assigned, checked, history)
        held, fresh = assigned.partition { run.known.key?(it[:id]) }

        follow_all(run, [*held, *checked], history)
        import_all(run, fresh)

        fresh.size + step(relate(run, assigned:, checked:)).size
      end

      def tracked(provider) = task_source_queries.for_provider(provider).to_h { [it.remote_id, it] }

      def unseen(run, assigned)
        run.known.except(*assigned.map { it[:id] }).values.select { it.due?(run.now) }.to_h { [it.remote_id, it.url] }
      end
    end
  end
end
