# frozen_string_literal: true

module Blog
  module DB
    module Plugins
      module ShortCoded
        CODE = Sequel[:short_codes][:code]
        LENGTH = Sequel.function(:length, CODE)
        OTHERS = Sequel[:others]

        def with_code
          short = ROM::SQL::Attribute[ROM::Types::String].meta(sql_expr: shortest).as(:short)
          qualified.join(:short_codes).select_append { |short_codes:| short_codes[:code] }.select_append(short)
        end

        private

        # The shortest start of the code that opens this record, as ADR 0194 resolves a path: no other code may be
        # that start whole, and no older code may begin with it. The whole code always opens its own record.
        def shortest
          lengths = dataset.db.from(Sequel.function(:generate_series, 1, LENGTH).as(:l))
          opened = lengths.where(Sequel.|({ l: LENGTH }, ~taken(Sequel.function(:left, CODE, :l)).exists))
          opened.select(Sequel.function(:left, CODE, Sequel.function(:min, :l)))
        end

        def taken(start)
          older = Sequel.&(OTHERS[:id] < Sequel[:short_codes][:id], Sequel.function(:starts_with, OTHERS[:code], start))
          dataset.db.from(Sequel[:short_codes].as(:others)).where(Sequel.|({ OTHERS[:code] => start }, older))
        end
      end
    end
  end
end
