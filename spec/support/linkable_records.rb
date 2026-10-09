# frozen_string_literal: true

module Spec
  module LinkableRecords
    FACTORIES = {
      "task" => %i[task title],
      "post" => %i[post title],
      "journal_entry" => %i[journal_entry body],
      "commit" => %i[commit message],
      "project" => %i[project name],
      "work_entry" => %i[work_entry role],
      "decision" => %i[decision title],
      "pull_request" => %i[pull_request title],
    }.freeze

    def linkable_record(kind, text = Faker::Lorem.sentence)
      return linkable_social_post(text) if kind == "social_post"

      factory, field = FACTORIES.fetch(kind)
      create(factory, field => text)
    end

    private

    def linkable_social_post(text)
      create(:social_post).tap { Social::Slice["relations.social_post_parts"].for_social_post(it.id).update(body: text) }
    end
  end
end

RSpec.configure do |config|
  config.include Spec::LinkableRecords
end
