# frozen_string_literal: true

Spec::DB::Factories.define(:social_post_part) do |f|
  f.sequence(:position) { |n| n }
  f.body { Faker::Lorem.sentence }
end
