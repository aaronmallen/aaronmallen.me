# frozen_string_literal: true

Spec::DB::Factories.define(:calendar_event) do |f|
  f.association(:calendar)
  f.sequence(:google_id) { "event-#{it}" }
  f.title "Platform standup"
  f.starts_on { Blog::TimeZone.today }
  f.ends_on { Blog::TimeZone.today }
end
