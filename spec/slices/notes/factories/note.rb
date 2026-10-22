# frozen_string_literal: true

Spec::DB::Factories.define(:note) do |f|
  f.sequence(:title) { |n| "Note #{n}" }
  f.body { Faker::Lorem.paragraph }
end
