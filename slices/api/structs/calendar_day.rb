# frozen_string_literal: true

module API
  module Structs
    CalendarDay = Data.define(:date, :sprint, :posts, :social_posts, :journal)
  end
end
