# frozen_string_literal: true

module GitHub
  class RateLimited < Error
    include Blog::RateLimited
  end
end
