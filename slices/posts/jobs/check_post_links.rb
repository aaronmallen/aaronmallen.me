# frozen_string_literal: true

module Posts
  module Jobs
    class CheckPostLinks < Blog::Job
      include Deps[check_post_links: "operations.check_post_links"]

      sidekiq_options retry: false

      def perform = check_post_links.call
    end
  end
end
