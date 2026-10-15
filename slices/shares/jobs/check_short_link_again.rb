# frozen_string_literal: true

module Shares
  module Jobs
    class CheckShortLinkAgain < Blog::Job
      include Deps[check_short_links: "operations.check_short_links"]

      sidekiq_options retry: 3

      def perform(id) = check_short_links.again(id)
    end
  end
end
