# frozen_string_literal: true

module Activity
  module Relations
    class Activities < Blog::DB::Relation
      use :crediting

      COMMENT = Blog::Types::ActivityKind["comment"]
      COMMIT = Blog::Types::ActivityKind["commit"]
      COMMIT_TOTALS = proc do
        [
          integer.count(source_id).as(:commits),
          integer.coalesce(integer.sum(additions), 0).as(:additions),
          integer.coalesce(integer.sum(deletions), 0).as(:deletions),
        ]
      end
      DECISION = Blog::Types::ActivityKind["decision"]
      DECISION_COMMENT = Blog::Types::ActivityKind["decision_comment"]
      JOURNAL = Blog::Types::ActivityKind["journal"]
      MONTH_FORMAT = "YYYY-MM"
      OWNER_SEPARATOR = "/"
      POST = Blog::Types::ActivityKind["post"]
      REPO_KINDS = %w[commit pull_request_closed pull_request_merged pull_request_opened].freeze
      SEARCHED = %i[excerpt link name repo sha status].freeze
      SESSION = Blog::Types::ActivityKind["session"]
      TASK = Blog::Types::ActivityKind["task"]
      TAGGED = {
        JOURNAL => %i[source_id journal_entry_tags],
        TASK => %i[source_id task_tags],
        COMMENT => %i[task_id task_tags],
        SESSION => %i[task_id task_tags],
        DECISION => %i[decision_id decision_tags],
        DECISION_COMMENT => %i[decision_id decision_tags],
      }.freeze
      LISTED = { **TAGGED, POST => %i[source_id post_tags] }.freeze
      TAGGINGS = Blog::DB::Plugins::Taggings
      TAG_NAME = Sequel.cast(Sequel[:tags][:name], :text)
      TARGET_SEPARATOR = " "

      schema :activities, infer: true

      def between(from, to) = where(occurred_on: from..to)

      def commit_totals_by_repo = unordered.where(type: COMMIT).select(:repo, &COMMIT_TOTALS).group(:repo).order(:repo)

      def commit_totals_by_repo_and_day
        commits = unordered.where(type: COMMIT).select(:repo, :occurred_on, &COMMIT_TOTALS)

        commits.group(:repo, :occurred_on).order(:repo, :occurred_on)
      end

      def counts_by_day
        unordered.select(:occurred_on) { integer.count(occurred_on).as(:count) }.group(:occurred_on).order(
          self[:occurred_on].desc,
        )
      end

      def counts_by_month
        counts = unordered.select(:type) do
          [string.to_char(occurred_on, MONTH_FORMAT).as(:month), integer.count(source_id).as(:count)]
        end

        counts.group(:type) { to_char(occurred_on, MONTH_FORMAT) }
      end

      def counts_by_type = unordered.select(:type) { integer.count(source_id).as(:count) }.group(:type)

      def in_repo(names)
        named = names.reject { unmatchable?(it) }.map { named_repo(it) }

        where(Sequel.|(Sequel.~(type: REPO_KINDS), *named))
      end

      def matching(text) = containing(text, *SEARCHED, Sequel.function(:array_to_string, :targets, TARGET_SEPARATOR))

      def newest_first
        order(self[:occurred_on].desc, self[:occurred_at].desc, self[:type].asc, self[:source_id].desc)
      end

      def oldest_first
        order(self[:occurred_on].asc, self[:occurred_at].asc, self[:type].asc, self[:source_id].asc)
      end

      def tagged(names)
        return none if unmatchable?(names)

        where(Sequel.|(*TAGGED.map { |type, (owner, table)| Sequel[type:] & Sequel[owner => holding(table, names)] }))
      end

      def with_tags
        lists = LISTED.to_h { |type, (owner, table)| [Sequel[type:], tag_names(owner, table)] }

        select_append(ROM::SQL::Attribute[ROM::Types::Any].meta(sql_expr: Sequel.case(lists, nil)).as(:tags))
      end

      def with_types(types) = where(type: types)

      private

      def holding(table, names) = TAGGINGS.holding_every(dataset.db, table, names)

      def named_repo(name)
        folded = name.to_s.downcase
        column = folded.include?(OWNER_SEPARATOR) ? Sequel[:repo] : owned_name

        Sequel[Sequel.function(:lower, column) => folded]
      end

      def owned_name = Sequel.function(:split_part, Sequel[:repo], OWNER_SEPARATOR, 2)

      def tag_names(owner, table)
        taggings = dataset.db[table].join(:tags, id: :tag_id).where(TAGGINGS.owner(table) => Sequel[:activities][owner])

        taggings.select(Sequel.function(:array_agg, TAG_NAME).order(TAG_NAME))
      end
    end
  end
end
