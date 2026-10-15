# frozen_string_literal: true

module Mastodon
  class RateLimited < Error
    include Blog::RateLimited
  end
end
