# frozen_string_literal: true

module Posts
  module Jobs
    class CheckPostLinks < Blog::ScheduledJob
      include Deps[check_post_links: "operations.check_post_links"]

      def perform = check_post_links.call
    end
  end
end
