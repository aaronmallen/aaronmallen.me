# frozen_string_literal: true

Spec::DB::Factories.define(:sprint) do |f|
  f.sequence(:sprint_date) { |n| Blog::TimeZone.today - (n - 1) }
end
