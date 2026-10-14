# frozen_string_literal: true

module Blog
  module Helpers
    module DayWindow
      LONGEST = 366
      TOO_LONG = "give a range of #{LONGEST} days or fewer".freeze
    end
  end
end
