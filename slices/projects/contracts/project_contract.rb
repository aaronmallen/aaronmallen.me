# frozen_string_literal: true

module Projects
  module Contracts
    class ProjectContract < Blog::Contract
      FUTURE = "future"
      MONTH = "%Y-%m"
      STARTED_ON = Blog::Types::Date.optional.constructor do |value|
        text = Blog::Types::TrimmedText[value]
        next nil if text.empty?

        Blog::Types::ProjectMonth.valid?(text) ? Date.strptime(text, MONTH) : text
      end

      params do
        required(:name).value(Blog::Types::TrimmedText, :filled?)
        required(:tagline).maybe(Blog::Types::OptionalText)
        required(:repo).maybe(Blog::Types::Nullable::Repo)
        required(:url).maybe(Blog::Types::Nullable::Url)
        required(:status).maybe(Blog::Types::Nullable::ProjectLiveStatus)
        required(:started_on).maybe(STARTED_ON)
        required(:tags).value(Blog::Types::TagList)
        required(:featured).value(Blog::Types::Checkbox)
        required(:og_image_url).maybe(Blog::Types::Nullable::Url)
      end

      rule(:name).validate(:without_controls)
      rule(:tagline).validate(:without_controls)
      rule(:url).validate(:without_controls)
      rule(:og_image_url).validate(:without_controls)

      rule(:started_on) do |context:|
        next if value.nil?

        key.failure(FUTURE) if value > context.fetch(:today)
      end

      rule(:tags).validate(:tag_slugs)
    end
  end
end
