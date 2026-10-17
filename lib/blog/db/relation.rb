# frozen_string_literal: true

require "hanami/db/relation"
require "blog/db/plugins"
require "blog/db/schema_inferrer"

module Blog
  module DB
    class Relation < Hanami::DB::Relation
      LINKABLE_ORDER = [Sequel.desc(:day), Sequel.desc(:id)].freeze
      LOCK_BUSY = Dry::Monads::Failure(:lock_busy)
      NUL = "\0"
      STAMPS = { create: %i[created_at updated_at], update: %i[updated_at] }.freeze

      schema_inferrer SchemaInferrer.new.freeze

      def self.lock_key(name) = Sequel.function(:hashtext, name)

      def self.site_day(*columns)
        moment = columns.one? ? columns.first : Sequel.function(:coalesce, *columns)

        Sequel.function(:timezone, TimeZone::NAME, moment).cast(Date)
      end

      def asleep(at = Time.now) = where(Sequel[:snoozed_until] > at)

      def awake(at = Time.now) = where(Sequel.|({ snoozed_until: nil }, Sequel[:snoozed_until] <= at))

      def capped_claim(fresh, visitor_hashes:, limit:, total_limit:)
        transaction do
          lock_until_commit
          from_sender, total = fresh.sender_counts(visitor_hashes)
          next unless from_sender < limit && total < total_limit

          yield
        end
      end

      def changed(columns)
        Sequel.is_distinct_from(columns.map { self[it].qualified }, columns.map { Sequel[:excluded][it] })
      end

      def containing(text, *columns, ids: Constants::EMPTY_ARRAY)
        return none if unmatchable?(text)

        pattern = like_pattern(text)
        found = columns.map { Sequel.ilike(it, pattern) }
        found << { self[:id].qualified => ids } unless ids.empty?

        where(Sequel.|(*found))
      end

      def counts_by(column) = unordered.select(column) { integer.count(id).as(:count) }.group(column)

      def excluded(columns) = columns.to_h { [it, Sequel[:excluded][it]] }

      def find_linkable(ids) = where(id: ids).linkable.map { Structs::Linkable.new(**it) }

      def latest_first(arrived, snoozed = self[:snoozed_until].qualified)
        order(Sequel.function(:greatest, self[arrived].qualified, snoozed).desc, self[:id].qualified.desc)
      end

      def like_pattern(text) = "%#{dataset.escape_like(text)}%"

      def linkables(title:, day:)
        columns = [:id, Sequel.as(title, :title), Sequel.as(day, :day)]

        dataset.select(*columns).order(*LINKABLE_ORDER)
      end

      def lock_senders_until_commit(senders)
        locks = senders.sort.map { Sequel.function(:pg_advisory_xact_lock, table_key, self.class.lock_key(it)) }

        dataset.db.select(*locks).first
      end

      def lock_until_commit(*keys) = dataset.db.get(Sequel.function(:pg_advisory_xact_lock, table_key, *keys))

      def newest_first = order(self[:created_at].desc, self[:id].desc)

      def none = where(false)

      def oldest_first = order(self[:created_at].asc, self[:id].asc)

      def paged(page) = limit(page.limit).offset(page.offset)

      def sender_counts(visitor_hashes)
        rows = Sequel.function(:count).*

        unordered.dataset.get([rows.filter(visitor_hash: visitor_hashes).as(:from_sender), rows.as(:total)])
      end

      def stamped(type, *columns, result: :one)
        timestamps = [*STAMPS.fetch(type), *columns]

        command(type, result:, use: :timestamps, plugins_options: { timestamps: { timestamps: } })
      end

      def tally(column, values = Constants::EMPTY_ARRAY)
        values.to_h { [it, 0] }.merge(counts_by(column).to_a.to_h { [it[column], it[:count]] })
      end

      def unmatchable?(*texts) = texts.flatten.any? { it.to_s.include?(NUL) }

      def with_advisory_lock(lock, busy: LOCK_BUSY)
        db = dataset.db
        key = self.class.lock_key(lock)

        db.synchronize do
          next busy unless db.get(Sequel.function(:pg_try_advisory_lock, key))

          begin
            yield
          ensure
            db.get(Sequel.function(:pg_advisory_unlock, key))
          end
        end
      end

      private

      def table_key = self.class.lock_key(name.dataset.to_s)
    end
  end
end
