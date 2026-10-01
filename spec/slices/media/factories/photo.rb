# frozen_string_literal: true

Spec::DB::Factories.define(:photo) do |f|
  f.sequence(:key) { |n| format("%032x.jpg", n) }
  f.width 640
  f.height 480
  f.byte_size 1024
end
