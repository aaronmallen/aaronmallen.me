# frozen_string_literal: true

module Google
  class RateLimited < Error
    include Blog::RateLimited
  end
end
