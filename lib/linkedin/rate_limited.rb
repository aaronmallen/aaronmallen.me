# frozen_string_literal: true

module LinkedIn
  class RateLimited < Error
    include Blog::RateLimited
  end
end
