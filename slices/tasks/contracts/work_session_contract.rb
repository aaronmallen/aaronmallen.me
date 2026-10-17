# frozen_string_literal: true

module Tasks
  module Contracts
    class WorkSessionContract < Blog::Contract
      params do
        required(:started_at).value(Blog::Types::LocalTime)
        optional(:ended_at).value(Blog::Types::LocalTime)
      end

      rule(:started_at).validate(:moment)
      rule(:started_at) { key.failure(BLANK) if value.nil? }

      rule(:ended_at).validate(moment: :closed?)
      rule(:ended_at) { |context:| key.failure(BLANK) if value.nil? && closed?(values, context) }

      private

      def closed?(_values, context) = !context[:running]
    end
  end
end
