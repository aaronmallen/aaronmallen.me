# frozen_string_literal: true

module MCP
  module Tools
    class ReadPerformance < Base
      RAW_DAYS = Performance::Repos::TimingReportQueries::RETENTION_DAYS
      TOP = API::Endpoints::ReadPerformance::TOP

      description "Read how long the site takes over a range. " \
                  "routes gives the top #{TOP} routes by p95, each a route and verb with its count of requests, " \
                  "p50 and p95 in milliseconds, and query_count and query_time, the queries its requests ran and " \
                  "the milliseconds they took, summed over the range. A null route is a request no route matched. " \
                  "jobs gives the top #{TOP} background jobs by p95 the same way. pages gives the browser figures " \
                  "the beacon sends, for the top #{TOP} routes by load p95: load, lcp (Largest Contentful Paint), " \
                  "ttfb and dom_content_loaded, each with its count, p50 and p95 in milliseconds, or null when no " \
                  "browser sent it. Pages count visits Cloudflare served from its cache, which never reach the " \
                  "server, so a route can show in pages and not in routes. The site keeps raw timing " \
                  "#{RAW_DAYS} days and each day's p50 and p95 for good, " \
                  "so p50 and p95 over a range of more than one day weigh each day's figure by its count. Give from " \
                  "and to as YYYY-MM-DD; both days count, days run on #{Blog::TimeZone::NAME} time, and the range " \
                  "runs at most #{API::Helpers::DayWindow::LONGEST} days"
      endpoint
    end
  end
end
