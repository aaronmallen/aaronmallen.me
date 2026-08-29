# frozen_string_literal: true

Spec::DB::Factories.define(:tag) do |f|
  f.sequence(:name) { |n| "tag-#{n}" }
  f.color { Blog::Types::TagColor.values.sample }
end
