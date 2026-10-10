# frozen_string_literal: true

require "hanami/db/relation"
require "blog/db/plugins"

module Blog
  module DB
    class Relation < Hanami::DB::Relation
      LINKABLE_ORDER = [Sequel.desc(:day), Sequel.desc(:id)].freeze
      NUL = "\0"
      STAMPS = { create: %i[created_at updated_at], update: %i[updated_at] }.freeze

      def self.site_day(*columns)
        moment = columns.one? ? columns.first : Sequel.function(:coalesce, *columns)

        Sequel.function(:timezone, TimeZone::NAME, moment).cast(Date)
      end

      def asleep(at = Time.now) = where(Sequel[:snoozed_until] > at)

      def awake(at = Time.now) = where(Sequel.|({ snoozed_until: nil }, Sequel[:snoozed_until] <= at))

      def capped_claim(fresh, visitor_hashes:, limit:, total_limit:)
        transaction do
          lock_until_commit
          next unless fresh.where(visitor_hash: visitor_hashes).count < limit && fresh.count < total_limit

          yield
        end
      end

      def containing(text, *columns)
        return none if unmatchable?(text)

        pattern = "%#{dataset.escape_like(text)}%"

        where(Sequel.|(*columns.map { Sequel.ilike(it, pattern) }))
      end

      def excluded(columns) = columns.to_h { [it, Sequel[:excluded][it]] }

      def find_linkable(ids: nil, text: nil, limit: nil)
        (text ? matching(text) : where(id: ids)).limit(limit).linkable
      end

      def linkables(title:, day:)
        columns = [:id, Sequel.as(title, :title), Sequel.as(day, :day)]

        dataset.select(*columns).order(*LINKABLE_ORDER).map { Structs::Linkable.new(**it) }
      end

      def lock_until_commit(*keys) = dataset.db.get(Sequel.function(:pg_advisory_xact_lock, table_key, *keys))

      def none = where(false)

      def paged(page) = limit(page.limit).offset(page.offset)

      def stamped(type, *columns, result: :one)
        timestamps = [*STAMPS.fetch(type), *columns]

        command(type, result:, use: :timestamps, plugins_options: { timestamps: { timestamps: } })
      end

      def unmatchable?(*texts) = texts.flatten.any? { it.to_s.include?(NUL) }

      def with_advisory_lock(key, busy: nil)
        db = dataset.db

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

      def table_key = Sequel.function(:hashtext, name.dataset.to_s)
    end
  end
end
