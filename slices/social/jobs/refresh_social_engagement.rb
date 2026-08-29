# frozen_string_literal: true

module Social
  module Jobs
    class RefreshSocialEngagement < Blog::Job
      include Deps[refresh_social_engagement: "operations.refresh_social_engagement"]

      sidekiq_options retry: false

      def perform
        refresh_social_engagement.call
      end
    end
  end
end
