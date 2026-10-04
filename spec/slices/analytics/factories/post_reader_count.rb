# frozen_string_literal: true

Spec::DB::Factories.define(:post_reader_count) do |f|
  f.sequence(:path) { |n| "/writing/post-#{n}" }
  f.readers 10
end
