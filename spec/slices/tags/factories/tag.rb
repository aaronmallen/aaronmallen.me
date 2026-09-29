# frozen_string_literal: true

Spec::DB::Factories.define(:tag) do |f|
  f.sequence(:name) { |n| "tag-#{n}" }
  f.color { Blog::Types::TagColor.values.sample }
  f.scope "public"

  f.trait :private do |t|
    t.scope "private"
  end
end
