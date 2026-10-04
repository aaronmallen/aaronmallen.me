# frozen_string_literal: true

module Admin
  module UniqueReaders
    NONE = { readers: nil, final: true }.freeze
    UNREAD = { readers: 0, final: false }.freeze

    def self.counted?(post, since) = post.published_at.nil? || post.published_at > since

    def self.of(post, counts, since: ::Analytics::Readers.window_opened_at)
      counts.fetch(path(post)) { counted?(post, since) ? UNREAD : NONE }
    end

    def self.path(post) = "#{Blog::Site::WRITING}/#{post.slug}"
  end
end
