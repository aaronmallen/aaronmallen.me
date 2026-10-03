# frozen_string_literal: true

module Tasks
  module Relations
    class TaskEvents < Blog::DB::Relation
      SPRINT_ON = Sequel[:sprints][:sprint_date].as(:sprint_on)
      TAG_NAME = Sequel[:tags][:name]
      TASK_ID = Sequel[:tasks][:id]

      schema :task_events, infer: true do
        associations do
          belongs_to :task
        end
      end

      def for_task(task_id) = where(task_id:)

      def in_order = order(self[:occurred_at].asc, self[:id].asc)

      def track(task_ids, at)
        dataset.db.transaction do
          before = states(task_ids)
          result = yield
          events = History.changes(before, states(before.keys), at)
          command(:create, result: :many).call(events) unless events.empty?
          result
        end
      end

      private

      def placements(task_ids)
        found = tasks.dataset.unordered.left_join(:sprints, id: :sprint_id).where(TASK_ID => task_ids)

        found.select(TASK_ID, :list, SPRINT_ON, :status)
      end

      def states(task_ids)
        tagged = tag_names(task_ids)

        placements(task_ids).to_h { [it[:id], { **it.except(:id), tags: tagged.fetch(it[:id], []) }] }
      end

      def tag_names(task_ids)
        tagged = task_tags.dataset.unordered.join(:tags, id: :tag_id).where(task_id: task_ids)

        tagged.select_hash_groups(:task_id, TAG_NAME)
      end
    end
  end
end
