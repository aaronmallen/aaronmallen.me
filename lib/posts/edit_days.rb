# frozen_string_literal: true

module Posts
  module EditDays
    def self.group(edits) = edits.group_by { Blog::TimeZone.today(it.created_at) }
  end
end
