# frozen_string_literal: true

Spec::DB::Factories.define(:post) do |f|
  f.title { Faker::Lorem.sentence }
  f.sequence(:slug) { |n| "post-#{n}" }
  f.body { Faker::Lorem.paragraphs.join("\n\n") }
  f.body_html { |body| Markdown.to_html(body) }
  f.first_paragraph { |body| Markdown::Document.new(body).first_paragraph }
  f.read_time { |body| Markdown::Document.new(body).read_time }
  f.word_count { |body| Markdown::Document.new(body).word_count }
  f.status "draft"
  f.published_at nil

  f.trait :draft do |t|
    t.status "draft"
    t.published_at nil
  end

  f.trait :scheduled do |t|
    t.status "scheduled"
    t.published_at { Time.now + (24 * 60 * 60) }
  end

  f.trait :published do |t|
    t.status "published"
    t.published_at { Time.now - (24 * 60 * 60) }
  end
end
