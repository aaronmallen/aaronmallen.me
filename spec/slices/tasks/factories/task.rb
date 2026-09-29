# frozen_string_literal: true

Spec::DB::Factories.define(:task) do |f|
  f.title { Faker::Lorem.sentence }
  f.list "next"
  f.status "open"
  f.sequence(:position) { |n| n }

  f.trait :canceled do |t|
    t.status "canceled"
    t.completed_at { Time.now }
  end

  f.trait :carried do |t|
    t.carried_count 2
  end

  f.trait :done do |t|
    t.status "done"
    t.completed_at { Time.now }
  end

  f.trait :in_progress do |t|
    t.status "in_progress"
  end

  f.trait :in_sprint do |t|
    t.list nil
    t.association(:sprint)
  end

  f.trait :someday do |t|
    t.list "someday"
  end
end
