# frozen_string_literal: true

module Shares
  module Jobs
    class FetchShortLinkTitle < Blog::Job
      include Deps[fetch_short_link_title: "operations.fetch_short_link_title"]

      sidekiq_options retry: false

      def perform(id) = fetch_short_link_title.call(id)
    end
  end
end
