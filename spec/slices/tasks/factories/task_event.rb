# frozen_string_literal: true

Spec::DB::Factories.define(:task_event) do |f|
  f.association(:task)
  f.kind "tagged"
  f.tag_name "money"
  f.occurred_at { Time.now }

  f.trait :carried do |t|
    t.kind "moved"
    t.tag_name nil
  end
end
