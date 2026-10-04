# frozen_string_literal: true

require "hanami/db/relation"

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

        dataset.select(*columns).order(*LINKABLE_ORDER).map { Linkable.new(**it) }
      end

      def none = where(false)

      def paged(page) = limit(page.limit).offset(page.offset)

      def stamped(type, *columns, result: :one)
        timestamps = [*STAMPS.fetch(type), *columns]

        command(type, result:, use: :timestamps, plugins_options: { timestamps: { timestamps: } })
      end

      def unmatchable?(*texts) = texts.flatten.any? { it.to_s.include?(NUL) }
    end
  end
end
