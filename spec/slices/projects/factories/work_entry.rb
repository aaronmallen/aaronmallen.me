# frozen_string_literal: true

Spec::DB::Factories.define(:work_entry) do |f|
  f.org { Faker::Lorem.word }
  f.role { Faker::Lorem.sentence }
  f.blurb { Faker::Lorem.sentence }
  f.from_year 2018
  f.to_year 2021
  f.sequence(:position) { |n| n }

  f.trait :current do |t|
    t.to_year nil
  end
end
