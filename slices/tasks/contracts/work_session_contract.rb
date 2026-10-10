# frozen_string_literal: true

module Tasks
  module Contracts
    class WorkSessionContract < Blog::Contract
      params do
        required(:started_at).value(Blog::Types::LocalTime)
        optional(:ended_at).value(Blog::Types::LocalTime)
      end

      rule(:started_at) do
        failure = moment_failure(value)
        key.failure(failure) if failure
      end

      rule(:ended_at) do |context:|
        failure = moment_failure(value) unless context[:running]
        key.failure(failure) if failure
      end

      private

      def moment_failure(value)
        case value
          when Time then nil
          when nil then BLANK
          when Blog::Constants::GAP then SKIPPED
          else FORMAT
        end
      end
    end
  end
end
