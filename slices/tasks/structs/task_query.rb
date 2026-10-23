# frozen_string_literal: true

module Tasks
  module Structs
    class TaskQuery < Data.define(:terms, :ignored)
      BLOCKS = Blog::Types::TaskLinkType["blocks"]
      CLOSED = Blog::Types::ClosedTaskStatus.values.freeze
      IN_PROGRESS = Blog::Types::TaskStatus["in_progress"]
      KEYS = {
        "col" => "column", "column" => "column", "is" => "is", "l" => "label", "label" => "label", "no" => "no",
      }.freeze
      STATUS = Sequel[:tasks][:status]
      TASK_ID = Sequel[:tasks][:id]
      TERM = /(?<sign>-?)(?<key>[a-z]+):(?:"(?<quoted>[^"]*)"|(?<bare>\S+))|"(?<phrase>[^"]*)"|(?<word>\S+)/i
      VALUES = {
        "column" => Blog::Types::TaskColumn.values,
        "is" => %w[open closed doing blocked],
        "no" => %w[label],
      }.freeze

      Term = Data.define(:key, :value, :negated)

      def self.parse(text)
        matches = text.to_s.delete(Blog::DB::Relation::NUL).to_enum(:scan, TERM).map { Regexp.last_match }
        terms, ignored = matches.map { read(it) }.partition { it.is_a?(Term) }

        new(terms:, ignored:)
      end

      def self.qualified(key, value, negated)
        value = value.tr(" -", "__") if key == "column"
        known = key == "label" ? value.split(",").any? : VALUES.fetch(key, []).include?(value)

        Term.new(key:, value:, negated:) if known
      end

      def self.read(match)
        return Term.new(key: nil, value: match[:phrase] || match[:word], negated: false) unless match[:key]

        key = match[:key].downcase
        value = (match[:quoted] || match[:bare]).downcase

        qualified(KEYS[key], value, !match[:sign].empty?) || "#{match[:sign]}#{key}:#{value}"
      end

      def conditions(db, label_ids)
        terms.map do |term|
          matched = condition(db, term, label_ids)
          term.negated ? Sequel.~(matched) : matched
        end
      end

      def texts = terms.filter_map { it.value unless it.key }

      private

      def blocked(db)
        blockers = db[:task_links].join(Sequel[:tasks].as(:blockers), id: :from_task_id)
        open_blockers = blockers.where(type: BLOCKS).exclude(Sequel[:blockers][:status] => CLOSED)

        Sequel.&(Sequel.~(STATUS => CLOSED), TASK_ID => open_blockers.select(:to_task_id))
      end

      def condition(db, term, label_ids)
        case term.key
          when nil then text(db, term.value, label_ids.fetch(term.value, Blog::Constants::EMPTY_ARRAY))
          when "label" then { TASK_ID => holding_any(db, term.value.split(",")) }
          when "no" then Sequel.~(TASK_ID => db[:task_tags].select(:task_id))
          when "column" then { Repos::TaskQueries::COLUMN => term.value }
          else status(db, term.value)
        end
      end

      def holding_any(db, names) = db[:task_tags].join(:tags, id: :tag_id).where(name: names).select(:task_id)

      def status(db, value)
        case value
          when "open" then Sequel.~(STATUS => CLOSED)
          when "closed" then { STATUS => CLOSED }
          when "doing" then { STATUS => IN_PROGRESS }
          else blocked(db)
        end
      end

      def text(db, value, ids)
        pattern = "%#{db.dataset.escape_like(value)}%"
        words = %i[title note].map { Sequel.ilike(Sequel[:tasks][it], pattern) }

        Sequel.|(*words, TASK_ID => ids)
      end
    end
  end
end
