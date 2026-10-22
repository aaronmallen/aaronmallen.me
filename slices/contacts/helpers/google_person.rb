# frozen_string_literal: true

module Contacts
  module Helpers
    module GooglePerson
      API = "https://people.googleapis.com/v1"
      FIELDS = %w[
        addresses biographies birthdays emailAddresses events fileAses imClients memberships names nicknames
        organizations phoneNumbers relations urls userDefined
      ].join(",")
      HANDLE_LINKS = { mastodon_handle: "Mastodon", bluesky_handle: "Bluesky" }.freeze
      STARRED = "contactGroups/starred"

      module_function

      def address(found)
        {
          street: found["streetAddress"], extended: found["extendedAddress"], city: found["city"],
          region: found["region"], postal_code: found["postalCode"], country: found["country"], type: found["type"],
        }
      end

      def addresses(person) = entries(person, "addresses") { address(it) }.select { it.except(:type).any? }

      def birthday(person) = partial_date(first(person, "birthdays")&.fetch("date", nil))

      def chats(person) = typed(person, "imClients", "username") { it["formattedProtocol"] || it["protocol"] }

      def compacted(entry) = entry.transform_values { text(it) }.compact

      def custom_fields(person)
        entries(person, "userDefined") { it.slice("key", "value").transform_keys(&:to_sym) }.select { it.size == 2 }
      end

      def dates(person)
        entries(person, "events") { { value: partial_date(it["date"]), type: it["type"] } }.select { it[:value] }
      end

      def entries(person, field, &) = person.fetch(field, []).map(&).map { compacted(it) }

      def first(person, field)
        found = person.fetch(field, [])

        found.find { it.dig("metadata", "primary") } || found.first
      end

      def google_id(person) = person.fetch("resourceName").delete_prefix("people/")

      def groups(rows)
        rows.select { it["groupType"] == "USER_CONTACT_GROUP" }.to_h { it.values_at("resourceName", "name") }
      end

      def labels(person, groups) = memberships(person).filter_map { groups[it] }.sort

      def lists(person)
        {
          emails: typed(person, "emailAddresses"), phones: typed(person, "phoneNumbers"), addresses: addresses(person),
          websites: websites(person), chats: chats(person), dates: dates(person),
          relations: typed(person, "relations", "person"), custom_fields: custom_fields(person),
        }
      end

      def memberships(person)
        person.fetch("memberships", []).filter_map { it.dig("contactGroupMembership", "contactGroupResourceName") }
      end

      def names(person)
        found = first(person, "names") || {}

        {
          name: "displayName", name_prefix: "honorificPrefix", given_name: "givenName", middle_name: "middleName",
          family_name: "familyName", name_suffix: "honorificSuffix", phonetic_given_name: "phoneticGivenName",
          phonetic_middle_name: "phoneticMiddleName", phonetic_family_name: "phoneticFamilyName",
        }.transform_values { text(found[it]) }
      end

      def organization(person)
        found = first(person, "organizations") || {}

        { company: "name", job_title: "title", department: "department" }.transform_values { text(found[it]) }
      end

      def partial_date(date)
        return unless date&.values_at("month", "day")&.all?

        year = date["year"] ? format("%<year>04d", year: date["year"]) : "-"

        format("%<year>s-%<month>02d-%<day>02d", year:, month: date["month"], day: date["day"])
      end

      def row(person, groups)
        {
          google_id: google_id(person), google_etag: text(person["etag"]), **names(person), **organization(person),
          **lists(person),
          nickname: value(person, "nicknames"), file_as: value(person, "fileAses"), notes: value(person, "biographies"),
          birthday: birthday(person), labels: labels(person, groups),
          starred: memberships(person).include?(STARRED),
        }
      end

      def text(value) = Blog::Types::OptionalText[value]

      def typed(person, field, key = "value", &type)
        entries(person, field) { { value: it[key], type: type ? yield(it) : it["type"] } }.select { it[:value] }
      end

      def value(person, field) = text(first(person, field)&.fetch("value", nil))

      def websites(person) = typed(person, "urls").reject { HANDLE_LINKS.value?(it[:type]) }
    end
  end
end
