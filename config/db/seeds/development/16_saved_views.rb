# frozen_string_literal: true

saved_views = SavedViews::Slice
return if saved_views["repos.saved_view_queries"].all.any?

create_saved_view = saved_views["operations.create_saved_view"]
[
  ["Drafts", "posts", { "status" => "draft" }],
  ["Home chores", "tasks", { "filter" => "next", "q" => "home" }],
  ["Garden notes", "journal", { "q" => "garden" }],
  ["Last week", "activity", { "from" => (Seeds.today - 7).iso8601, "to" => Seeds.today.iso8601 }],
].each { |name, screen, filters| Seeds.unwrap(create_saved_view.call({ name:, screen:, filters: })) }
