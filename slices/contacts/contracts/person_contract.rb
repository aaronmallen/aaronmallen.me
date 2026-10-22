# frozen_string_literal: true

module Contacts
  module Contracts
    class PersonContract < Blog::Contract
      BLUESKY_FORMAT = /\A(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z][a-z0-9-]{0,61}[a-z0-9]\z/
      MASTODON_FORMAT = /\A@\w+(?:[.-]\w+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z][a-z0-9-]*[a-z0-9]\z/i
      PARTIAL_DATE_FORMAT = /\A(?:\d{4}|-)-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\d|3[01])\z/
      TEXTS = %i[
        name name_prefix given_name middle_name family_name name_suffix
        phonetic_given_name phonetic_middle_name phonetic_family_name
        nickname file_as company job_title department notes
      ].freeze

      BLUESKY_HANDLE = Blog::Types::String.constrained(format: BLUESKY_FORMAT).optional.constructor do |value|
        Blog::Types::OptionalText[value]&.delete_prefix("@")&.downcase
      end
      EMAIL = Blog::Types::EmailAddress.constructor { Blog::Types::TrimmedText[it] }
      KEY = Blog::Types::Tag.optional.constructor { Blog::Types::OptionalText[it]&.downcase }
      LABELS = Blog::Types::Array.of(Blog::Types::String).constructor do |labels|
        Array(labels).filter_map { Blog::Types::OptionalText[it] }.uniq
      end
      MASTODON_HANDLE = Blog::Types::String.constrained(format: MASTODON_FORMAT).optional.constructor do |value|
        Blog::Types::OptionalText[value]
      end
      PARTIAL_DATE = Blog::Types::String.constrained(format: PARTIAL_DATE_FORMAT).constructor do |value|
        Blog::Types::TrimmedText[value]
      end
      TEXT = Blog::Types::OptionalText
      VALUE = Blog::Types::TrimmedText
      ENTRIES = {
        emails: EMAIL, phones: VALUE, websites: VALUE, chats: VALUE, dates: PARTIAL_DATE, relations: VALUE,
      }.freeze

      params do
        TEXTS.each { optional(it).maybe(TEXT) }
        optional(:key).maybe(KEY)
        optional(:mastodon_handle).maybe(MASTODON_HANDLE)
        optional(:bluesky_handle).maybe(BLUESKY_HANDLE)
        ENTRIES.each do |list, value|
          optional(list).array(:hash) do
            required(:value).filled(value)
            optional(:type).maybe(TEXT)
          end
        end
        optional(:addresses).array(:hash) do
          %i[street extended city region postal_code country type].each { optional(it).maybe(TEXT) }
        end
        optional(:custom_fields).array(:hash) do
          required(:key).filled(VALUE)
          required(:value).filled(VALUE)
        end
        optional(:birthday).maybe(PARTIAL_DATE)
        optional(:labels).value(LABELS)
        optional(:starred).filled(:bool)
      end

      TEXTS.each { rule(it).validate(:without_controls, :visible) }
    end
  end
end
