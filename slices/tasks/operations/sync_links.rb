# frozen_string_literal: true

module Tasks
  module Operations
    class SyncLinks < Operation
      ENDS = %i[from_task_id to_task_id].freeze
      FAILURES = [ROM::SQL::UniqueConstraintError, ROM::SQL::ForeignKeyConstraintError].freeze
      KINDS = Structs::Link::LABELS.each_with_object({}) do |(type, sides), kinds|
        sides.each { |side, kind| kinds[kind] ||= [type, side] }
      end.freeze
      RANKS = Structs::Link::ORDER
      RELATES = Blog::Types::TaskLinkType["relates"]

      include Deps[task_link_repo: "repos.task_link_repo"]

      def call(known, issues)
        heard = heard(known, issues)
        rows = task_link_repo.touching_all(heard.keys)
        live = live(known, heard, rows)

        transaction { settle(rows, wanted(known, heard.slice(*live), live), live) }
      end

      private

      def add(link) = write { task_link_repo.add_synced(**link) }

      def change(row, link) = same?(row, link) || write { task_link_repo.update(row.id, **link) }

      def ends(link) = link.to_h.values_at(*ENDS)

      def heard(known, issues)
        issues.each_with_object({}) do |issue, heard|
          source = known[issue[:id]]
          heard[source.task_id] = issue[:relations] if source && issue.key?(:relations)
        end
      end

      def key(link) = ends(link).minmax

      def link(id, other, kind)
        type, side = KINDS[kind]
        return unless type && other && other != id

        from, to = side == :outgoing ? [id, other] : [other, id]
        { from_task_id: from, to_task_id: to, type: }
      end

      def live(known, heard, rows)
        named = heard.values.flatten.filter_map { known[it[:remote_id]]&.task_id }

        task_link_repo.open_ids([*heard.keys, *named, *rows.flat_map { ends(it) }]).to_set
      end

      def live?(link, live) = ends(link).all? { live.include?(it) }

      def owned?(row, live) = row.synced && live?(row, live)

      def prune(gone) = gone.empty? || task_link_repo.delete(gone.map(&:id))

      def same?(row, link)
        return row.type == link[:type] if link[:type] == RELATES

        row.to_h.slice(*link.keys) == link
      end

      def settle(rows, wanted, live)
        kept, gone = rows.select { owned?(it, live) }.partition { wanted.key?(key(it)) }

        prune(gone)
        kept.each { change(it, wanted.fetch(key(it))) }
        wanted.except(*rows.map { key(it) }).each_value { add(it) }
      end

      def strongest(links) = links.min_by { RANKS.index(it[:type]) }

      def wanted(known, heard, live)
        links = heard.flat_map do |id, relations|
          relations.filter_map { link(id, known[it[:remote_id]]&.task_id, it[:kind]) }
        end

        links.select { live?(it, live) }.group_by { key(it) }.transform_values { strongest(it) }
      end

      def write(&)
        task_link_repo.transaction(&)
      rescue *FAILURES
        nil
      end
    end
  end
end
