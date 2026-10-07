# frozen_string_literal: true

return if Tasks::Slice["repos.sprint_queries"].after(Seeds.today - 365).any?

capture_task = Tasks::Slice["operations.capture_task"]
current_sprint = Tasks::Slice["operations.current_sprint"]
schedule_task = Tasks::Slice["operations.schedule_task"]

capture = lambda do |title, list: "next", note: "", tags: ""|
  Seeds.unwrap(capture_task.call({ title:, note:, tags: }, filter: list)).last
end

in_sprint = lambda do |title, days_ago, **fields|
  at = Seeds.ago(days_ago, hour: 8)
  Seeds.unwrap(current_sprint.call(now: at))
  task = capture.call(title, **fields)
  Seeds.unwrap(schedule_task.call(task.id, (Seeds.today - days_ago).iso8601, now: at))
  task
end

complete_task = Tasks::Slice["operations.complete_task"]
cancel_task = Tasks::Slice["operations.cancel_task"]

shipped = in_sprint.call("Write the release notes", 14, tags: "writing")
carried = in_sprint.call("Sort the receipts drawer", 14, note: "Keep the tax ones apart.", tags: "home,chores")
Seeds.unwrap(complete_task.call(shipped.id, at: Seeds.ago(13, hour: 16)))
dropped = in_sprint.call("Call the plumber back", 7, tags: "home")
Seeds.unwrap(cancel_task.call(dropped.id, at: Seeds.ago(6, hour: 12)))
Seeds.unwrap(current_sprint.call)

move_task = Tasks::Slice["operations.move_task"]
started = capture.call("Draft the seeds post", tags: "writing")
finished = capture.call("Water the plants", tags: "home")
waiting = capture.call("Book the dentist", tags: "health,errands")
[started, finished, waiting].each { Seeds.unwrap(move_task.call(it.id, "today")) }
Seeds.unwrap(Tasks::Slice["operations.start_task"].call(started.id))
Seeds.unwrap(complete_task.call(finished.id))

upcoming = capture.call("Plan the garden beds", note: "Order seed packets first.", tags: "home")
Seeds.unwrap(schedule_task.call(upcoming.id, (Seeds.today + 3).iso8601))
Seeds.unwrap(Tasks::Slice["operations.plan_sprint"].call((Seeds.today + 7).iso8601))

blocker = capture.call("Pick a paint colour", tags: "home")
blocked = capture.call("Paint the hallway", note: "Two coats, then the trim.", tags: "home,chores")
related = capture.call("Fix the hallway light", tags: "home")
original = capture.call("Renew the library card", tags: "errands,reading")
copy = capture.call("Renew library card", tags: "errands")
someday = capture.call("Learn to bind books", list: "someday", tags: "reading")
capture.call("Read the Postgres release notes", list: "someday", tags: "reading")
canceled = capture.call("Sell the old monitor", tags: "errands")
Seeds.unwrap(cancel_task.call(canceled.id))

link_tasks = Tasks::Slice["operations.link_tasks"]
Seeds.unwrap(link_tasks.call(blocked.id, { kind: "blocked_by", other_id: blocker.id }))
Seeds.unwrap(link_tasks.call(blocked.id, { kind: "relates", other_id: related.id }))
Seeds.unwrap(link_tasks.call(copy.id, { kind: "duplicates", other_id: original.id }))
Seeds.unwrap(link_tasks.call(someday.id, { kind: "blocks", other_id: original.id }))

add_comment = Tasks::Slice["operations.add_task_comment"]
Seeds.unwrap(add_comment.call(blocked.id, { body: "The landlord says any neutral colour is fine." }))
Seeds.unwrap(add_comment.call(blocked.id, { body: "Bought two tins of **eggshell**." }))
Seeds.unwrap(add_comment.call(carried.id, { body: "Still waiting on the bank statement." }))

issue = lambda do |number, title, state, labels: [], comments: []|
  url = "https://example.com/example/widgets/issues/#{number}"

  {
    body: "Raised from the widgets tracker.", comments:, id: "issue-#{number}", labels:,
    reference: "example/widgets##{number}", remote_state: state, repo: "example/widgets", title:, url:,
  }
end

Seeds.unwrap(
  Tasks::Slice["operations.sync_issues"].call(
    provider: "github",
    client: Seeds::IssueClient.new(
      [
        issue.call(
          41, "Widgets crash on an empty list", "open",
          labels: %w[bug chores],
          comments: [
            {
              author: "octo-example", body: "Seen on the latest build too.", created_at: Seeds.ago(2),
              id: "comment-41-1", url: "https://example.com/example/widgets/issues/41#comment-1",
            },
          ],
        ),
        issue.call(42, "Document the config file", "started", labels: %w[writing]),
        issue.call(43, "Drop the old export format", "completed"),
      ],
    ),
  ),
)
