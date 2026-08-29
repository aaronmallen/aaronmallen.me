# frozen_string_literal: true

module Tasks
  module Jobs
    class RollOverSprint < Blog::Job
      class RollOverFailed < StandardError; end

      include Deps[current_sprint: "operations.current_sprint"]

      sidekiq_options retry: false

      def perform
        current_sprint.call.or { raise RollOverFailed, it.to_s }
      end
    end
  end
end
