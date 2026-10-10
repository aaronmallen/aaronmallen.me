# frozen_string_literal: true

module Social
  module Jobs
    class RefreshSocialEngagement < Blog::ScheduledJob
      include Deps[refresh_social_engagement: "operations.refresh_social_engagement"]

      def perform
        refresh_social_engagement.call
      end
    end
  end
end
