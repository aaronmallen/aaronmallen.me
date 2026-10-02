# frozen_string_literal: true

projects = Projects::Slice

if projects["queries.live"].call.empty? && projects["queries.archived"].call.empty?
  save_project = projects["operations.save_project"]
  project = lambda do |name, tagline, repo, status, started_on, tags, featured: false|
    params = {
      name:, tagline:, repo:, url: nil, status:, started_on:, tags:, og_image_url: nil,
      featured: featured ? Blog::Constants::CHECKED : nil,
    }

    Seeds.unwrap(save_project.call(params))
  end

  project.call("Blog", "This site.", "example/blog", "active", "2025-03", "hanami,ruby", featured: true)
  project.call("Widgets", "A small widget toolkit.", "example/widgets", "wip", "2025-11", "ruby,tooling")
  project.call("Domain Kit", "Shared Postgres domains.", "example/domain-kit", "paused", "2024-06", "postgres")
  retired = project.call("Old Theme", "The theme this site used to wear.", "example/old-theme", nil, "2022-01", "")
  Seeds.unwrap(projects["operations.archive_project"].call(retired.id, on: Date.new(2025, 2, 1)))
end

if projects["queries.work_entries"].call.empty?
  [
    { org: "Example Corp", role: "Staff Engineer", blurb: "Platform and tooling.", from_year: "2022", to_year: nil },
    { org: "Sample Labs", role: "Senior Engineer", blurb: "Billing and reports.", from_year: "2018", to_year: "2022" },
    { org: "Demo Co", role: "Engineer", blurb: nil, from_year: "2014", to_year: "2018" },
  ].each { Seeds.unwrap(projects["operations.add_work_entry"].call(it)) }
end
