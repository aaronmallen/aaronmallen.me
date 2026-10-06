# frozen_string_literal: true

Spec::DB::Factories.define(:task_link) do |f|
  f.association(:from_task)
  f.association(:to_task)
  f.type "blocks"

  f.trait :duplicates do |t|
    t.type "duplicates"
  end

  f.trait :parent do |t|
    t.type "parent"
  end

  f.trait :relates do |t|
    t.type "relates"
  end
end
