# frozen_string_literal: true

require "dry/operation"

module Blog
  class Operation < Dry::Operation
    module Savepoint
      def transaction(**, &) = super(savepoint: true, **, &)
    end
    private_constant :Savepoint

    def self.inherited(klass)
      super
      klass.prepend(Savepoint)
    end

    private

    def affected(count) = count.positive? ? Success(count) : Failure(:not_found)

    def each_record(ids)
      transaction { ids.map { |id| step(yield(id).alt_map { [:record, id, it] }) } }
    end

    def found(value) = value ? Success(value) : Failure(:not_found)

    def snoozed(record, now) = record&.snoozed_until&.>(now) ? Success(record) : Failure(:not_snoozed)

    def validated(result) = result.to_monad.fmap(&:to_h).alt_map { [:invalid, it.errors.to_h] }
  end
end
