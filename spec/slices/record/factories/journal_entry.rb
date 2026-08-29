# frozen_string_literal: true

Spec::DB::Factories.define(:journal_entry) do |f|
  f.entry_date { Blog::TimeZone.today }
  f.entry_time "09:00"
  f.body { Faker::Lorem.paragraph }
end
