# frozen_string_literal: true

performance = Performance::Slice
return if performance["repos.rollup_queries"].newest_day

timing = performance["repos.timing_mutations"]
random = Random.new(1946)
routes = { "/" => 40.0, "/writing/:slug" => 55.0, "/admin" => 120.0, "/admin/tasks" => 180.0 }
device_classes = %w[desktop mobile]
jobs = { "Tasks::Jobs::SyncIssues" => 900.0, "Analytics::Jobs::RollUpAnalytics" => 300.0 }

14.downto(1) do |days_ago|
  routes.each do |route, typical|
    6.times do
      duration = typical * random.rand(0.5..2.5)
      at = Seeds.ago(days_ago, hour: 8 + random.rand(12), minute: random.rand(60))
      timing.record_request(
        route:, verb: "GET", status: 200, duration:, query_count: random.rand(2..18),
        query_time: duration / 3, occurred_at: at,
      )
      next if route.start_with?("/admin")

      timing.record_page(
        route:, device_class: device_classes.sample(random:), ttfb: duration, dom_content_loaded: duration + 120,
        load: duration + 340, lcp: duration + 480, occurred_at: at,
      )
    end
  end

  jobs.each do |job, typical|
    failed = days_ago == 4 && job.include?("SyncIssues")
    timing.record_job(
      job:, outcome: failed ? "failed" : "succeeded", duration: typical * random.rand(0.6..1.8),
      query_count: random.rand(5..40), query_time: typical / 4, occurred_at: Seeds.ago(days_ago, hour: 3),
      error_class: ("Blog::ServiceError" if failed), error_message: ("GitHub answered 502" if failed),
    )
  end
end

performance["operations.roll_up_timing"].call
