# frozen_string_literal: true

module Social
  module Structs
    Engagement = Data.define(:like_count, :reply_count, :repost_count)
  end
end
