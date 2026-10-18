# frozen_string_literal: true

module Admin
  module Operations
    class BuildSettingsTabs
      UNKNOWN = "!"

      include Deps[
        cron_queries: "activity.repos.cron_queries", job_queries: "activity.repos.job_queries",
        list_services: "operations.list_services", person_queries: "social.repos.person_queries",
        task_rule_queries: "tasks.repos.task_rule_queries",
      ]

      def call(
        socials: person_queries.count, tagging: task_rule_queries.count, services: list_services.count, jobs: self.jobs
      )
        { socials:, tagging:, services:, jobs: }
      end

      def jobs(flagged: job_queries.flagged, failed: nil)
        return UNKNOWN unless flagged

        flagged + (failed || cron_queries.failed)
      end
    end
  end
end
