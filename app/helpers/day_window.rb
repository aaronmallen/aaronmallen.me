# frozen_string_literal: true

module Blog
  module Helpers
    module DayWindow
      LONGEST = 366
      TOO_LONG = "give a range of #{LONGEST} days or fewer".freeze

      module_function

      def too_long?(first, last) = last - first >= LONGEST
    end
  end
end
