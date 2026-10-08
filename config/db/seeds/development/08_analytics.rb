# frozen_string_literal: true

require "securerandom"

analytics = Analytics::Slice
return if analytics["repos.analytics_rollup_queries"].days(from: Seeds.today - 30, to: Seeds.today).any?

pages = {
  "/" => "Aaron Allen",
  "/writing" => "Writing",
  "/writing/moving-the-blog-to-hanami-3" => "Moving the blog to Hanami 3",
  "/writing/domains-in-postgres" => "Domains in Postgres",
  "/projects" => "Projects",
  "/about" => "About",
}
agents = [
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
  "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 " \
  "Safari/604.1",
  "Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 " \
  "Safari/604.1",
  "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Mobile Safari/537.36 " \
  "Bluesky",
]
hosts = [nil, nil, "news.example.com", "search.example.org", "links.example.net"]
sources = [nil, nil, nil, "bluesky", "mastodon", "newsletter"]
countries = ["US", "US", "GB", "DE", "CA", "NL", nil]
depths = [0, 25, 50, 75, 100]

classify_device = analytics["operations.classify_device"]
hash_visitor = analytics["operations.hash_visitor"]
events = analytics["repos.analytics_event_mutations"]
random = Random.new(236)

21.downto(0) do |days_ago|
  (4 + random.rand(9)).times do |visitor|
    address = "198.51.100.#{visitor + 1}"
    user_agent = agents.sample(random:)
    at = Seeds.ago(days_ago, hour: 7 + random.rand(12), minute: random.rand(60))
    next if at > Time.now

    visit = {
      visitor_hash: hash_visitor.call(address:, user_agent:, at:),
      month_visitor_hash: hash_visitor.call(address:, user_agent:, at:, period: Analytics::Operations::HashVisitor::MONTH),
      address_hash: hash_visitor.call(address:, at:),
      country_code: countries.sample(random:),
      device_class: classify_device.call(user_agent),
    }
    trail = pages.keys.sample(1 + random.rand(3), random:)

    trail.each_with_index do |path, step|
      first = step.zero?

      events.create(
        **visit,
        path:,
        title: pages.fetch(path),
        view_token: SecureRandom.hex(16),
        occurred_at: at + (step * 90),
        referrer_host: (hosts.sample(random:) if first),
        referrer_path: (trail[step - 1] unless first),
        source: (sources.sample(random:) if first),
        read_seconds: random.rand(15..400),
        scroll_depth: depths.sample(random:),
      )
    end
  end
end

analytics["operations.roll_up_analytics"].call
