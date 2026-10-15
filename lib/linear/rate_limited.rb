# frozen_string_literal: true

module Linear
  class RateLimited < Error
    include Blog::RateLimited
  end
end
