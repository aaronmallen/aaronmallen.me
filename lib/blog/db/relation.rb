# frozen_string_literal: true

require "hanami/db/relation"

module Blog
  module DB
    class Relation < Hanami::DB::Relation
      STAMPS = { create: %i[created_at updated_at], update: %i[updated_at] }.freeze

      def excluded(columns) = columns.to_h { [it, Sequel[:excluded][it]] }

      def paged(page) = limit(page.limit).offset(page.offset)

      def stamped(type, *columns, result: :one)
        timestamps = [*STAMPS.fetch(type), *columns]

        command(type, result:, use: :timestamps, plugins_options: { timestamps: { timestamps: } })
      end
    end
  end
end
