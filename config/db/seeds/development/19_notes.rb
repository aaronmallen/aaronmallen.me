# frozen_string_literal: true

notes = Notes::Slice
return if notes["repos.note_queries"].count.nonzero?

folder = ->(path) { path && Seeds.unwrap(notes["operations.create_note_folder_path"].call(path)).id }
Seeds.unwrap(
  notes["operations.describe_note_folder"].call(folder.call("Reference"), { description: "Things I look up." }),
)

create_note = notes["operations.create_note"]
start, = [
  [
    "Start here", nil, "",
    "Things I want to find again.\n\n## Work\n\n- [[Postgres indexing cheatsheet]]\n- [[Hanami slices]]\n" \
    "- [[Gem release checklist]]\n\n## Home\n\n- [[Coffee ratios]]\n- [[House maintenance]]\n- [[Paint colours]]",
  ],
  [
    "Postgres indexing cheatsheet", "Reference", "postgres",
    "## Composite indexes\n\nPut the column you filter with equality first, the range column last.\n\n" \
    "```sql\nCREATE INDEX CONCURRENTLY activities_kind_day_index ON activities (kind, occurred_on);\n```\n\n" \
    "See [[Hanami slices]] for where the repo lives.",
  ],
  [
    "Hanami slices", "Reference", "hanami,ruby",
    "Each slice owns its actions, views and relations.\n\n- No slice reaches into another slice's repos.\n" \
    "- Shared code goes in `lib/` once two slices need it.\n\nIndexes: [[Postgres indexing cheatsheet]].",
  ],
  [
    "Gem release checklist", "Reference/Ruby", "ruby",
    "1. Changelog entry under the new version.\n2. Bump `VERSION` and run the full matrix.\n" \
    "3. Tag, push, `gem push`.\n4. Release notes, then a [[Post ideas|post]].",
  ],
  [
    "Post ideas", "Ideas", "writing",
    "- What I learned rebuilding this site, again\n- Seeds that go through the front door\n" \
    "- Pattern matching for event streams",
  ],
  ["Coffee ratios", "Home", "", "- V60: 15g to 250g, 94°C, 3:00 total\n- AeroPress: 17g to 220g, 1:45"],
  [
    "House maintenance", "Home", "home",
    "## Every 3 months\n\n- Furnace filter (20×25×1)\n\n## Every fall\n\n- Gutters\n" \
    "- Blow out the sprinklers\n\nThe plumber is in contacts as *Dale Example*.",
  ],
].map do |title, path, tags, body|
  Seeds.unwrap(create_note.call({ title:, body:, folder_id: folder.call(path), tags: }))
end

Seeds.unwrap(notes["operations.pin_note"].call(start.id, { pinned: true }))
