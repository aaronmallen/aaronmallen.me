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
        task_source_mutations: "repos.task_source_mutations",
        task_source_queries: "repos.task_source_queries",
        task_rule_queries: "repos.task_rule_queries",
      ]

      def call(provider:, client:, now: Time.now)
        run = Structs::IssueSyncRun.new(provider:, client:, now:, known: task_source_queries.for_provider(provider))
        listing, checked, history = step fetch(run)
        count = sync_all(run, listing.items, checked, history)

        listing.cut_short? ? step(Failure(:page_limit)) : count
      end

      private

      def close_or_reopen(run, source, task, state, changes)
        settle_task.call(task, from: source.remote_state, to: state, at: run.now, history: changes).value!
      end

      def copy(issue)
        title, note = issue.values_at(:title, :body).map { it&.delete("\0") }

        { title: title&.match?(VISIBLE) ? title : issue.fetch(:reference), note: }
      end

      def create_task(run, issue, reached: false)
        transaction do
          task = file(run, issue)
          fields = { task_id: task.id, remote_id: issue[:id], url: issue[:url], remote_state: OPEN }
          sync_comments.hold(run, [task.id], [issue])
          task_source_mutations.create(**fields, provider: run.provider).tap { refresh(run, it, task, issue, reached:) }
        end
      end

      def fetch(run)
        remote(run.client, run.provider) do
          listing = run.client.assigned_issues
          assigned = listing.items.uniq { it[:id] }
          checked = run.client.issues(run.unseen(assigned))

          Success([listing.with(items: assigned), checked, history(run, [*assigned, *checked])])
        end
      end

      def file(run, issue)
        names, project_ids = task_rule_queries.targets(run.provider, issue[:origin])
        task = task_mutations.append(**copy(issue), list: EXTERNAL, project_id: project_ids.first)
        task_event_mutations.track(task.id, run.now) { task_mutations.import_tags(task.id, labels(issue), names) }
        task
      end

      def follow(run, issues, history)
        sources = issues.map { run.known.fetch(it[:id]) }
        task_ids = sources.map(&:task_id)
        tasks = task_source_queries.followed_tasks(task_ids)
        run.linked.concat(task_link_queries.synced_ids(task_ids))
        sync_comments.hold(run, task_ids, issues)

        issues.zip(sources, tasks) { |issue, source, task| task && refresh(run, source, task, issue, history:) }
      end

      def history(run, issues)
        return EMPTY_HASH unless run.client.respond_to?(:transitions)

        run.client.transitions(issues, run.known.transform_values(&:history_cursor).compact)
      end

      def import(run, issues, reached: false)
        issues.each { run.track(create_task(run, it, reached:)) }
      end

      def labels(issue) = issue.fetch(:labels, EMPTY_ARRAY).filter_map { LABEL_TAG.call(it) { nil } }

      def reach(run, assigned)
        remote(run.client, run.provider) { Success(reach_issues.call(run.client, assigned, run.known)) }
      end

      def refresh(run, source, task, issue, history: EMPTY_HASH, reached: false)
        state = state_to_store(run, task, source, issue, reached)
        changes = history[issue[:id]]
        stamp = source.restamp(state, issue, changes, run.now)
        return run.check(source, stamp) if source.quiet?(stamp) && unchanged?(run, source, task, issue, changes)

        transaction do
          task = close_or_reopen(run, source, task, state, changes)
          rewrite(task, issue)
          task_source_mutations.update(source.id, **stamp) if stamp
          sync_comments.call(source, task, issue, run)
        end
      end

      def relate(run, assigned:, checked:)
        reached = reach(run, assigned).fmap { import(run, it, reached: true) }
        sync_links.call(run.known, [*assigned, *checked, *reached.value_or(EMPTY_ARRAY)])
        reached
      end

      def retitled?(task, issue) = issue.key?(:title) && copy(issue) != { title: task.title, note: task.note }

      def rewrite(task, issue) = retitled?(task, issue) && task_mutations.update(task.id, **copy(issue))

      def state_to_store(run, task, source, issue, reached)
        state = issue.fetch(:remote_state)
        return source.remote_state if source.remote_state == UNASSIGNED && CLOSED.valid?(state)
        return state if state != UNASSIGNED || task.closed?

        reached || run.linked.include?(task.id) ? OPEN : state
      end

      def sync_all(run, assigned, checked, history)
        held, fresh = assigned.partition { run.known.key?(it[:id]) }

        follow(run, [*held, *checked], history)
        import(run, fresh)
        task_source_mutations.check(run.checked, run.now)

        fresh.size + step(relate(run, assigned:, checked:)).size
      end

      def unchanged?(run, source, task, issue, changes)
        changes.to_a.empty? && !retitled?(task, issue) && sync_comments.quiet?(source, task, issue, run)
      end
    end
  end
end
