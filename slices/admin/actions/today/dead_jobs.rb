# frozen_string_literal: true

module Admin
  module Actions
    module Today
      class DeadJobs < Action
        include Deps[attention_queries: "activity.repos.attention_queries"]

        def handle(request, response)
          page = requested_page(request, response)
          jobs = page.fill(attention_queries.dead_jobs(limit: page.limit, offset: page.offset))
          not_found(response) if jobs.past_end?

          response[:count] = attention_queries.dead_job_count
          response[:jobs] = jobs
        end
      end
    end
  end
end
