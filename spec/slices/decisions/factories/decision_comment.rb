# frozen_string_literal: true

Spec::DB::Factories.define(:decision_comment) do |f|
  f.association(:decision)
  f.body { Faker::Lorem.paragraph }
end
