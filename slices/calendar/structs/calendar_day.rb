# frozen_string_literal: true

module Calendar
  module Structs
    CalendarDay = Data.define(:date, :sprint, :posts, :social_posts, :journal, :events)
  end
end
