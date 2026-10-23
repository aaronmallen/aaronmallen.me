# frozen_string_literal: true

calendar = Calendar::Slice
return if calendar["repos.calendar_queries"].listed.any?

event = lambda do |id, title, days_from_now, hours = nil, place: nil, attendees: [], notes: nil, meet: false|
  day = Seeds.today + days_from_now
  times = hours&.map { Blog::TimeZone.local_time(*Seeds.date_parts(day), it, 0) }

  {
    google_id: id, title:, starts_on: day, ends_on: day, starts_at: times&.first, ends_at: times&.last, place:,
    meet_url: ("https://meet.example.com/#{id}" if meet), attendees:, notes:,
    link: "https://calendar.example.com/event/#{id}", recurring_id: nil,
  }
end

held = lambda do |google_id, name, writable, events|
  { google_id:, name:, writable:, synced_from: Seeds.today - 90, sync_token: nil, events:, cancelled: [], full: true }
end

calendar["repos.calendar_mutations"].store(
  "ada@example.com",
  [
    held.call(
      "ada@example.com", "Home", true,
      [
        event.call("dentist", "Dentist", 2, [9, 10], place: "Example Dental"),
        event.call("garden", "Plant the garden beds", 5),
        event.call("lunch", "Lunch with Grace", 1, [12, 13], place: "Corner Cafe", attendees: ["Grace Example"]),
        event.call("plumber", "Plumber visit", -3, [8, 9], notes: "Main line check."),
        event.call("trip", "Weekend away", 9).merge(ends_on: Seeds.today + 11),
      ],
    ),
    held.call(
      "work@example.com", "Work", false,
      [
        event.call("standup", "Standup", 0, [9, 10], meet: true, attendees: ["Ada Example", "Linus Example"]),
        event.call("review", "Design review", 3, [14, 15], meet: true, attendees: ["Ada Example"]),
        event.call("oncall", "On call", 7),
      ],
    ),
  ],
  to: Seeds.today + 365,
)
