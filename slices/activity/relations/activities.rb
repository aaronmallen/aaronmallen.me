# frozen_string_literal: true

module Activity
  module Relations
    class Activities < Blog::DB::Relation
      COMMENT = Blog::Types::ActivityKind["comment"]
      COMMIT = Blog::Types::ActivityKind["commit"]
      COMMIT_TOTALS = proc do
        [
          integer.count(source_id).as(:commits),
          integer.coalesce(integer.sum(additions), 0).as(:additions),
          integer.coalesce(integer.sum(deletions), 0).as(:deletions),
        ]
      end
      JOURNAL = Blog::Types::ActivityKind["journal"]
      MATCHED = Sequel.function(:count, Sequel[:tags][:name]).distinct
      MONTH_FORMAT = "YYYY-MM"
      OWNER_SEPARATOR = "/"
      SEARCHED = %i[excerpt link name repo sha status].freeze
      TASK = Blog::Types::ActivityKind["task"]
      TAGGED = {
        JOURNAL => %i[source_id journal_entry_tags journal_entry_id],
        TASK => %i[source_id task_tags task_id],
        COMMENT => %i[task_id task_tags task_id],
      }.freeze
      TARGET_SEPARATOR = " "

      schema :activities, infer: true

      def between(from, to) = where(occurred_on: from..to)

      def commit_totals_by_repo = unordered.where(type: COMMIT).select(:repo, &COMMIT_TOTALS).group(:repo).order(:repo)

      def counts_by_month
        counts = unordered.select(:type) do
          [string.to_char(occurred_on, MONTH_FORMAT).as(:month), integer.count(source_id).as(:count)]
        end

        counts.group(:type) { to_char(occurred_on, MONTH_FORMAT) }
      end

      def counts_by_type = unordered.select(:type) { integer.count(source_id).as(:count) }.group(:type)

      def day_count = unordered.dataset.select(:occurred_on).distinct.count

      def in_repo(names)
        where(Sequel.|(Sequel.~(Sequel[type: COMMIT]), *names.map { named_repo(it) }))
      end

      def matching(text)
        pattern = "%#{dataset.escape_like(text)}%"
        columns = [*SEARCHED, Sequel.function(:array_to_string, :targets, TARGET_SEPARATOR)]

        where(Sequel.|(*columns.map { Sequel.ilike(it, pattern) }))
      end

      def newest_first
        order(self[:occurred_on].desc, self[:occurred_at].desc, self[:type].asc, self[:source_id].desc)
      end

      def tagged(names)
        folded = names.map { it.to_s.downcase }.uniq

        where(Sequel.|(*TAGGED.map { |type, (owner, table, key)| owners_tagged(type, owner, table, key, folded) }))
      end

      def with_types(types) = where(type: types)

      private

      def named_repo(name)
        folded = name.to_s.downcase
        column = folded.include?(OWNER_SEPARATOR) ? Sequel[:repo] : owned_name

        Sequel[Sequel.function(:lower, column) => folded]
      end

      def owned_name = Sequel.function(:split_part, Sequel[:repo], OWNER_SEPARATOR, 2)

      def owners_tagged(type, owner, table, key, names)
        Sequel[type:] & Sequel[owner => tag_owners(table, key, names)]
      end

      def tag_owners(table, key, names)
        owner = Sequel[table][key]
        taggings = dataset.db[table].join(:tags, id: :tag_id)

        taggings.where(Sequel[:tags][:name] => names).group(owner).having(MATCHED => names.length).select(owner)
      end
    end
  end
end
