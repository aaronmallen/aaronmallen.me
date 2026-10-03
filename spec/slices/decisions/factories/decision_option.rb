# frozen_string_literal: true

Spec::DB::Factories.define(:decision_option) do |f|
  f.association(:decision)
  f.title { Faker::Lorem.sentence }
  f.body { Faker::Lorem.paragraph }
end
