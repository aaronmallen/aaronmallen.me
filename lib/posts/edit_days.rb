# frozen_string_literal: true

module Posts
  module EditDays
    def self.newest_first(edits) = edits.group_by { Blog::TimeZone.today(it.created_at) }.to_a.reverse
  end
end
