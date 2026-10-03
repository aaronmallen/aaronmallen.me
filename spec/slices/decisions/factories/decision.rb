# frozen_string_literal: true

Spec::DB::Factories.define(:decision) do |f|
  f.title { Faker::Lorem.sentence }
  f.problem { Faker::Lorem.paragraph }
  f.status "open"
end
