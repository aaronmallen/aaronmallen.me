# frozen_string_literal: true

module Analytics
  module UniqueReaders
    NONE = { readers: nil, final: true }.freeze
    UNREAD = { readers: 0, final: false }.freeze

    def self.counted?(post, since) = post.published_at.nil? || post.published_at > since

    def self.of(post, counts, since: Readers.window_opened_at)
      counts.fetch(path(post)) { counted?(post, since) ? UNREAD : NONE }
    end

    def self.path(post) = "#{Blog::Site::WRITING}/#{post.slug}"

    def self.read(post, readers_by_path) = of(post, readers_by_path.call([path(post)]))
  end
end
