# frozen_string_literal: true

module Posts
  module Jobs
    class CheckPostLinksAgain < Blog::Job
      include Deps[check_post_links: "operations.check_post_links"]

      def perform(post_id, url = nil) = check_post_links.again(post_id, url:)
    end
  end
end
