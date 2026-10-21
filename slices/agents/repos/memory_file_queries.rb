# frozen_string_literal: true

module Agents
  module Repos
    class MemoryFileQueries < Blog::DB::Repo
      def agent_changes(on: Blog::TimeZone.today)
        memory_events.where(created_at: Range.new(*Blog::TimeZone.day_bounds(on, on), true)).exclude(agent: nil).count
      end

      def by_id(id) = memory_files.combine(:memory_facts).by_pk(id).one

      def event(memory_file_id, id) = memory_events.where(memory_file_id:).by_pk(id).one

      def fact_count = memory_facts.where(removed_at: nil).count

      def history(memory_file_id, page) = page.fill(memory_events.where(memory_file_id:).newest_first.paged(page).to_a)

      def history_count(memory_file_id) = memory_events.where(memory_file_id:).count

      def history_marks(events)
        ids = events.map(&:id)

        {
          latest: memory_events.latest_by_fact(events.filter_map(&:memory_fact_id).uniq),
          reverted: memory_events.where(reverted_event_id: ids).pluck(:reverted_event_id).to_set,
          undone: memory_events.where(id: events.filter_map(&:reverted_event_id)).pluck(:id, :op).to_h,
        }
      end

      def latest_events(memory_file_ids)
        memory_events.latest_by_file(memory_file_ids).to_a.to_h { [it.memory_file_id, it] }
      end

      def listed(scope: nil, query: nil)
        found = memory_files.combine(:memory_facts)
        found = found.where(scope:) if scope
        found = found.containing(query, :path, ids: holding(query)) if query

        found.in_load_order.to_a
      end

      def loaded(repo:, project_ids:, task_ids:)
        memory_files.combine(:memory_facts).loading(repo:, project_ids:, task_ids:).in_load_order.to_a
      end

      def repos = memory_files.exclude(repo: nil).order(:repo).distinct.pluck(:repo)

      def scope_counts = memory_files.tally(:scope, Blog::Types::MemoryScope.values)

      def searched(page, text:, scope: nil, within: nil)
        files = within ? memory_files.loading(**within) : memory_files
        files = files.where(scope:) if scope
        facts = memory_facts.combine(:memory_file).where(memory_file_id: files.pluck(:id))

        page.fill(facts.live_in_order.containing(text, :text).paged(page).to_a)
      end

      private

      def holding(query) = memory_facts.live_in_order.containing(query, :text).pluck(:memory_file_id).uniq
    end
  end
end
