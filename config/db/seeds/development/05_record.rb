# frozen_string_literal: true

return if Record::Slice["repos.journal_entry_queries"].count.nonzero?

save_entry = Record::Slice["operations.save_journal_entry"]
[
  [20, "Moved the blog to Hanami today. The slices make the code easy to find.", "home"],
  [16, "Slow day. Read two chapters and walked to the library.", "reading"],
  [12, "Fixed the drip under the sink at last.", "home,chores"],
  [9, "Wrote about Postgres domains. The post took longer than the code.", ""],
  [5, "Dentist reminder came in the post. Booked nothing yet.", "health"],
  [2, "Planned the garden beds on paper.", "home"],
  [0, "Seeded the development database. Every page has something on it now.", ""],
].each do |days_ago, body, tags|
  Seeds.unwrap(save_entry.call({ body:, entry_date: nil, tags: }, now: Seeds.ago(days_ago, hour: 21)))
end

store_commits = Record::Slice["operations.store_commits"]
{
  "example/blog" => [[18, "Add the seeds loader", 40, 2], [9, "Write the domains post", 120, 8], [1, "Fix typo", 1, 1]],
  "example/widgets" => [[11, "Handle an empty list", 25, 4], [3, "Drop the old export format", 3, 210]],
}.each do |repo, commits|
  store_commits.call(
    repo,
    [
      {
        name: "main",
        commits: commits.map do |days_ago, message, additions, deletions|
          sha = Digest::SHA1.hexdigest("#{repo}#{message}")

          { sha:, message:, additions:, deletions:, authored_at: Seeds.ago(days_ago, hour: 15) }
        end,
      },
    ],
  )
end

Record::Slice["operations.record_linear_issue_sync_outcome"].call(
  Dry::Monads::Result::Failure.new([:linear_failed, "Linear answered 503 Service Unavailable"]),
)
