# frozen_string_literal: true

decisions = Decisions::Slice
return if decisions["repos.decision_queries"].count_by_status.values.sum.positive?

open_decision = decisions["operations.open_decision"]
add_option = decisions["operations.add_decision_option"]
add_comment = decisions["operations.add_decision_comment"]

decision = lambda do |title, problem, tags, options, comments|
  opened = Seeds.unwrap(open_decision.call({ title:, problem:, tags: }))
  picked = options.map { |name, body| Seeds.unwrap(add_option.call(opened.id, { title: name, body: })) }
  comments.each { Seeds.unwrap(add_comment.call(opened.id, { body: it })) }
  [opened, picked]
end

decision.call(
  "Where should the share files live?",
  "The NAS holds every share today. A second copy would survive a dead disk, but costs money each month.",
  "tooling",
  [
    ["Keep them on the NAS", "Free, and the backups already cover it."],
    ["Copy them to object storage", "About two dollars a month at the current size."],
  ],
  ["The NAS backup runs nightly, so a dead disk loses one day at most."],
)

paint, (eggshell, _matte) = decision.call(
  "Which finish for the hallway?",
  "The hallway takes the most scuffs in the house.",
  "home",
  [["Eggshell", "Wipes clean and hides small marks."], ["Matte", "Looks better but shows every scuff."]],
  ["The landlord says any neutral colour is fine.", "Two tins of **eggshell** are in the garage already."],
)
Seeds.unwrap(
  decisions["operations.resolve_decision"].call(
    paint.id, { option_id: eggshell.id, reason: "It wipes clean, and the tins are already here." },
  ),
)

dropped, = decision.call(
  "Move the blog to a static host?",
  "A static host would cut the server bill, but the admin needs a database.",
  "hanami",
  [["Stay on the Pi", "Costs nothing new."]],
  [],
)
Seeds.unwrap(
  decisions["operations.drop_decision"].call(dropped.id, { reason: "The admin needs the server anyway." }),
)
