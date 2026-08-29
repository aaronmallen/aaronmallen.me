# frozen_string_literal: true

Spec::DB::Factories.define(:task_type) do |f|
  f.sequence(:name) { |n| "Type #{n}" }
  f.color { Blog::Types::TagColor.values.sample }
  f.icon { Blog::Types::TaskTypeIcon.values.sample }
  f.sequence(:position) { |n| n }
end
