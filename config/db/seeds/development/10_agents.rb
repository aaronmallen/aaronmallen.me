# frozen_string_literal: true

agents = Agents::Slice
return if agents["repos.memory_file_queries"].listed.any?

agent = { agent: "claude-code", model: "claude-opus-5-5" }
project_id = Seeds.unwrap(agents["operations.find_project"].call(repo: "example/blog"))

session = lambda do |title, at, branch|
  params = { title:, **agent, client: "Claude Code on macOS", repo: "example/blog", branch:, task_ids: [] }

  Seeds.unwrap(agents["operations.start_session"].call(params, at:)).first
end

profiling = session.call("Profile the date range search", Seeds.ago(2, hour: 15), "main")
indexing = session.call("Index the activities table for date range search", Seeds.ago(1, hour: 8), "activities-index")
reviewing = session.call("Review the seeds post", Time.now - (Seeds::HOUR / 2), "seeds-post")

create_file = agents["operations.create_memory_file"]
add_fact = agents["operations.add_memory_fact"]
memory = lambda do |path, description, facts, session_id:, **scope|
  file = Seeds.unwrap(create_file.call({ path:, description:, **scope, **agent, session_id: }))
  facts.each { |type, text| Seeds.unwrap(add_fact.call(file.id, { type:, text:, **agent, session_id: })) }
  file
end

style = memory.call(
  "code-style.md", "No comments, few constants; read before writing code.",
  [
    ["preference", "Write no comments in code. Rework names or structure instead."],
    ["preference", "Never pull a value into a constant that only one place reads."],
  ],
  scope: "global", session_id: profiling,
)
memory.call(
  "writing.md", "Plain words and short sentences; read before writing docs or posts.",
  [["preference", "Cut every word you can. Never use a long word where a short one will do."]],
  scope: "global", session_id: profiling,
)
app = memory.call(
  "architecture.md", "Slice layout and where shared code lives; read before adding code.",
  [
    ["convention", "No slice reaches into another slice's repos."],
    ["gotcha", "Run every tool through a mise task; a bare rubocop reads no config."],
    ["context", "The activities query filters by kind, then by day."],
  ],
  scope: "project", project_id:, session_id: indexing,
)
agents["operations.record_read"].call(indexing, style.id, at: Seeds.ago(1, hour: 8, minute: 5))
agents["operations.record_read"].call(reviewing, app.id)

create_artifact = agents["operations.create_artifact"]
plan = Seeds.unwrap(
  create_artifact.call(
    {
      title: "Index the activities table for date range search", type: "plan", tags: %w[postgres],
      body: "## Goal\n\nDate range search on activities runs a sequential scan.\n\n" \
            "## Steps\n\n1. Add a composite index on kind and day.\n2. Measure p95 before and after.",
      **agent, session_id: profiling,
    },
  ),
)
Seeds.unwrap(
  agents["operations.update_artifact"].call(
    plan.id,
    {
      title: plan.title, type: "plan", tags: %w[postgres],
      body: "## Goal\n\nDate range search on activities runs a sequential scan.\n\n" \
            "## Steps\n\n1. Add a composite index on kind and day.\n2. Measure p95 before and after.\n\n" \
            "## Result\n\np95 fell from 180ms to 12ms.",
      note: "Added the result after the index landed", **agent, session_id: indexing,
    },
  ),
)
[
  [
    "Handoff: activities index, end of session", "handoff",
    "## Done\n\n- Composite index added.\n\n## Next\n\n- Watch p95 for a day.", indexing,
  ],
  [
    "Review of the seeds post", "review",
    "## Summary\n\nThe post reads well. Two fixes before it ships.\n\n" \
    "1. Name the mise task in the first paragraph.\n2. Cut the history section.", reviewing,
  ],
  ["Hanami upgrade notes", "notes", "- Router slice blocks take a `to:` option.\n- Assets need Node 20.", nil],
].each do |title, type, body, session_id|
  Seeds.unwrap(create_artifact.call({ title:, type:, tags: %w[hanami], body:, **agent, session_id: }))
end

end_session = agents["operations.end_session"]
Seeds.unwrap(end_session.call(profiling, at: Seeds.ago(2, hour: 16, minute: 30)))
Seeds.unwrap(end_session.call(indexing, at: Seeds.ago(1, hour: 10, minute: 12)))
