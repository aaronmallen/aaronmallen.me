# frozen_string_literal: true

module Admin
  module Helpers
    module ContactForm
      ADDRESS = %i[street extended city region postal_code country].freeze
      ENTRIES = %i[emails phones websites chats dates relations].freeze
      NAME = %i[name_prefix given_name middle_name family_name].freeze
      ROWS = ENTRIES.to_h { [it, %i[value type]] }
                    .merge(addresses: [*ADDRESS, :type], custom_fields: %i[key value]).freeze
      TEXTS = %i[
        name_prefix given_name middle_name family_name name_suffix
        phonetic_given_name phonetic_middle_name phonetic_family_name nickname file_as
        company job_title department key mastodon_handle bluesky_handle birthday notes
      ].freeze
      FILLED = { addresses: ADDRESS, custom_fields: %i[key value] }.freeze

      module_function

      def errors(errors) = errors.transform_values { first_codes(it) }

      def fields(values)
        texts = TEXTS.to_h { [it, Blog::Types::OptionalText[values[it]]] }

        { **values, **texts, name: name(values) }
      end

      def first_codes(codes) = codes.is_a?(Hash) ? first_codes(codes.values.first) : codes

      def labels(given)
        added = Blog::Types::Normalized::LabelTag.call(given[:new_label]) { nil }

        [*Array(given[:labels]).map { Blog::Types::TrimmedText[it] }, added].reject { it.nil? || it.empty? }.uniq
      end

      def lists(person) = ROWS.to_h { |list, _| [list, person.public_send(list).map { it.transform_keys(&:to_sym) }] }

      def name(values)
        given = NAME.filter_map { Blog::Types::OptionalText[values[it]] }.join(" ")
        return if given.empty?

        suffix = Blog::Types::OptionalText[values[:name_suffix]]
        suffix ? "#{given}, #{suffix}" : given
      end

      def prefill(values, name: nil, email: nil)
        name = Blog::Types::OptionalText[name]
        email = Blog::Types::OptionalText[email]
        values = values.merge(split(name)) if name && NAME.all? { values[it].empty? }
        values = values.merge(emails: [{ value: email }]) if email && values[:emails].empty?
        values
      end

      def read(params)
        given = Blog::Types::Fields[params]

        {
          **TEXTS.to_h { [it, Blog::Types::TrimmedText[given[it]]] },
          **ROWS.to_h { |list, keys| [list, rows(list, given[list], keys)] },
          labels: labels(given), starred: given[:starred] == Blog::Constants::CHECKED,
        }
      end

      def rows(list, given, keys)
        filled = FILLED.fetch(list, keys.first(1))

        Array(given).filter_map do |row|
          kept = keys.to_h { [it, Blog::Types::TrimmedText[Blog::Types::Fields[row][it]]] }.reject { _2.empty? }
          kept if filled.any? { kept.key?(it) }
        end
      end

      def split(name)
        given, family = name.split(" ", 2)

        { given_name: given.to_s, family_name: family.to_s }
      end

      def values(person)
        return read(Blog::Constants::EMPTY_HASH) unless person

        texts = TEXTS.to_h { [it, person.public_send(it).to_s] }
        texts.merge!(split(person.name)) if person.name && [*NAME, :name_suffix].all? { texts[it].empty? }

        { **texts, **lists(person), labels: person.labels.to_a, starred: person.starred }
      end
    end
  end
end
