# frozen_string_literal: true

module Projects
  module Jobs
    class RefreshProject < Blog::Job
      include Deps[refresh_project: "operations.refresh_project"]

      sidekiq_options retry: false

      def perform(id) = refresh_project.call(id)
    end
  end
end
