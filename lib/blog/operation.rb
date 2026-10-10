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

    def contract_keys = contract.schema.key_map.map(&:id)

    def each_record(ids)
      transaction { ids.map { |id| step(yield(id).alt_map { [:record, id, it] }) } }
    end

    def every_field(params) = contract_keys.to_h { [it, params[it]] }

    def found(value) = value ? Success(value) : Failure(:not_found)

    def moved_to_day(time, day, now)
      at = TimeZone.on_day(time, day)

      at > now ? Success(at) : Failure(:past)
    rescue TZInfo::PeriodNotFound
      Failure(:invalid)
    end

    def snoozed(record, now) = record&.snoozed_until&.>(now) ? Success(record) : Failure(:not_snoozed)

    def upcoming_day(date, now)
      day = TimeZone.parse_day(date)
      return Failure(:invalid) unless day

      day >= TimeZone.today(now) ? Success(day) : Failure(:past)
    end

    def validated(result) = result.to_monad.fmap(&:to_h).alt_map { [:invalid, it.errors.to_h] }
  end
end
