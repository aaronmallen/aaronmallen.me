# frozen_string_literal: true

module Tasks
  module Relations
    class Tasks < Blog::DB::Relation
      COMPLETED_ON = Sequel.function(:timezone, Blog::TimeZone::NAME, :completed_at).cast(Date)
      CREATED_ON = Sequel.function(:timezone, Blog::TimeZone::NAME, :created_at).cast(Date)
      CLOSED = [Blog::Types::TaskStatus["done"], Blog::Types::TaskStatus["canceled"]].freeze
      IN_PROGRESS = Blog::Types::TaskStatus["in_progress"]
      LISTS = Blog::Types::TaskList.values.freeze
      OPEN = Blog::Types::TaskStatus["open"]
      TABLE_KEY = Sequel.function(:hashtext, "tasks")

      schema :tasks, infer: true do
        associations do
          belongs_to :sprint
          has_many :task_links, as: :incoming_links, foreign_key: :to_task_id
          has_many :task_links, as: :outgoing_links, foreign_key: :from_task_id
          has_many :task_tags
          has_many :tags, through: :task_tags, view: :in_name_order
          has_one :task_sources, as: :source
          has_one :work_sessions, as: :running_session, view: :running
        end
      end

      def carry_into(sprint_id)
        stamped(:update, result: :many).call(carried_count: Sequel[:carried_count] + 1, sprint_id:).size
      end

      def closed = where(status: CLOSED)

      def detailed = combine(:running_session, :source, :tags, incoming_links: :from_task, outgoing_links: :to_task)

      def finished_counts(day)
        closed.unordered.select do
          [integer.count(id).as(:total), integer.count(id).filter(COMPLETED_ON => day).as(:on_day)]
        end
      end

      def following(task)
        where(Sequel.|(Sequel[:position] > task.position, Sequel.&({ position: task.position }, Sequel[:id] > task.id)))
          .in_order
      end

      def for_sprint(sprint_id) = where(sprint_id:)

      def in_list(list) = where(list:)

      def in_order = order(self[:position].asc, self[:id].asc)

      def in_progress = where(status: IN_PROGRESS)

      def last_position = unordered.max(:position).to_i

      def linkable = linkables(title: :title, day: self.class.site_day(:completed_at, :created_at))

      def linkable_from(id) = exclude(id:).exclude(id: task_links.partner_ids(id).dataset)

      def list_counts = select_append { LISTS.map { integer.count(id).filter(list: it).as(it.to_sym) } }

      def lock_positions_until_commit = dataset.db.get(Sequel.function(:pg_advisory_xact_lock, TABLE_KEY))

      def matching(text) = containing(text, :title, :note)

      def narrowed(statuses:, from:, to:, lists: [], sprint_on: nil, **search)
        found = searched(**search)
        found = found.where(status: statuses) unless statuses.empty?
        found = found.in_list(lists) unless lists.empty?
        found = found.for_sprint(sprints.on(sprint_on).ids) if sprint_on
        from || to ? found.touched_between(from, to) : found
      end

      def newest_first = order(Sequel.function(:coalesce, :completed_at, :created_at).desc, self[:id].desc)

      def open = exclude(status: CLOSED)

      def open_counts(sprint_id, planned_ids)
        counted = open.unordered.select do
          [
            integer.count(id).filter(sprint_id:).as(:today),
            integer.count(id).filter(sprint_id: planned_ids).as(:upcoming),
          ]
        end

        counted.list_counts
      end

      def open_first = order(Sequel.case({ { status: CLOSED } => 1 }, 0), self[:position].asc, self[:id].asc)

      def pause(at)
        running = in_progress
        work_sessions.close(running.dataset.select(:id), at)
        running.stamped(:update, result: :many).call(status: OPEN)
      end

      def preceding(task)
        where(Sequel.|(Sequel[:position] < task.position, Sequel.&({ position: task.position }, Sequel[:id] < task.id)))
          .order(self[:position].desc, self[:id].desc)
      end

      def searched(tags: [], text: "")
        found = self
        found = found.matching(text) unless text.empty?
        tags.empty? ? found : found.tagged(tags)
      end

      def sourced = where(id: task_sources.task_ids)

      def tagged(names)
        return none if unmatchable?(names)

        where(id: holding_every(names.map { it.to_s.downcase }.uniq).dataset)
      end

      def titled(text) = containing(text, :title)

      def titles_and_totals(ids) = dataset.unordered.where(id: ids).select_hash(:id, %i[title worked_seconds])

      def totals_closed_between(first, last)
        found = exclude(worked_seconds: 0).exclude(id: work_sessions.select(:task_id).dataset)
        closed = found.where(COMPLETED_ON => first..last).dataset.unordered

        closed.select_map([:id, COMPLETED_ON.as(:closed_on), :worked_seconds])
      end

      def touched_between(first, last)
        days = Range.new(first, last)

        where(Sequel.|({ CREATED_ON => days }, { COMPLETED_ON => days }))
      end

      def unfinished_in(sprint_ids) = where(sprint_id: sprint_ids).open

      def unsourced = exclude(id: task_sources.task_ids)

      private

      def holding_every(names)
        owner = task_tags[:task_id].qualified
        name = tags[:name].qualified
        matched = task_tags.unordered.join(:tag).where(name => names)

        matched.group(owner).having(Sequel.function(:count, name).distinct => names.length).select(owner)
      end
    end
  end
end
