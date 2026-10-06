# frozen_string_literal: true

module Tasks
  module Contracts
    class WorkedContract < Blog::Contract
      HOUR = 3600
      HOURS = (0..9999)
      MINUTES = (0..59)

      params do
        optional(:hours).maybe(:integer)
        optional(:minutes).maybe(:integer)
        optional(:tracked).maybe(:integer)
      end

      rule(:hours) { key.failure(FORMAT) if value && !HOURS.cover?(value) }

      rule(:minutes) { key.failure(FORMAT) if value && !MINUTES.cover?(value) }

      rule(:hours, :minutes) do |context:|
        key(:hours).failure(BLANK) if context[:required] && values[:hours].nil? && values[:minutes].nil?
      end

      def self.seconds(fields)
        return if fields[:hours].nil? && fields[:minutes].nil?

        (fields[:hours].to_i * HOUR) + (fields[:minutes].to_i * Blog::Figures::MINUTE)
      end
    end
  end
end
