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

    def each_record(ids)
      transaction { ids.map { |id| step(yield(id).alt_map { [:record, id, it] }) } }
    end

    def validated(result) = result.to_monad.fmap(&:to_h).alt_map { [:invalid, it.errors.to_h] }
  end
end
