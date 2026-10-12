# frozen_string_literal: true

module Calendar
  module Structs
    class CalendarEvent < Blog::DB::Struct
      def all_day? = starts_at.nil?
    end
  end
end
