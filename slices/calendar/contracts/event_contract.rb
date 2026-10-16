# frozen_string_literal: true

module Calendar
  module Contracts
    class EventContract < Blog::Contract
      CLOCK = /\A(?:[01]\d|2[0-3]):[0-5]\d\z/
      ENDS_FIRST = "ends_first"

      params do
        required(:title).value(Blog::Types::TrimmedText, :filled?)
        required(:date).filled(:date)
        required(:all_day).maybe(:bool)
        required(:starts).maybe(Blog::Types::OptionalText)
        required(:ends).maybe(Blog::Types::OptionalText)
        required(:place).maybe(Blog::Types::OptionalText)
      end

      rule(:title).validate(:without_controls, :visible)
      rule(:place).validate(:without_controls)

      rule(:starts, :ends, :all_day) do |context:|
        next if values[:all_day]

        clocks = values.values_at(:starts, :ends)
        later_day = context[:span]&.positive?
        next key(:ends).failure(ENDS_FIRST) if !later_day && clocks.all? { it&.match?(CLOCK) } && clocks[1] <= clocks[0]

        %i[starts ends].each { key(it).failure(FORMAT) unless values[it]&.match?(CLOCK) }
      end
    end
  end
end
