# frozen_string_literal: true

module Bluesky
  class RateLimited < Error
    include Blog::RateLimited
  end
end
