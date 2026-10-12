# frozen_string_literal: true

Spec::DB::Factories.define(:calendar) do |f|
  f.account "aaron@example.com"
  f.sequence(:google_id) { "calendar-#{it}@group.calendar.google.com" }
  f.sequence(:name) { "Calendar #{it}" }
  f.writable true
end
