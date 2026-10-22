# frozen_string_literal: true

module Contacts
  module Helpers
    module GoogleBody
      DATE = /\A(\d{4}|-)-(\d\d)-(\d\d)\z/
      MY_CONTACTS = "contactGroups/myContacts"
      NAME_PARTS = {
        name_prefix: "honorificPrefix", given_name: "givenName", middle_name: "middleName", family_name: "familyName",
        name_suffix: "honorificSuffix", phonetic_given_name: "phoneticGivenName",
        phonetic_middle_name: "phoneticMiddleName", phonetic_family_name: "phoneticFamilyName",
      }.freeze
      SOURCES = {
        "names" => [:name, *NAME_PARTS.keys], "nicknames" => [:nickname],
        "organizations" => %i[company job_title department], "biographies" => [:notes],
        "emailAddresses" => [:emails], "phoneNumbers" => [:phones], "addresses" => [:addresses],
        "urls" => [:websites, *GooglePerson::HANDLE_LINKS.keys], "imClients" => [:chats], "events" => [:dates],
        "relations" => [:relations], "userDefined" => [:custom_fields], "birthdays" => [:birthday],
        "memberships" => %i[labels starred],
      }.freeze

      module_function

      def about(contact)
        {
          "names" => present(names(contact)), "nicknames" => values(contact[:nickname]),
          "organizations" => present(organization(contact)), "biographies" => notes(contact),
          "birthdays" => contact[:birthday] ? [{ date: date(contact[:birthday]) }] : [], "events" => dates(contact),
          "relations" => typed(contact[:relations], :person), "userDefined" => contact[:custom_fields].map(&:to_h),
        }
      end

      def address(entry)
        {
          streetAddress: entry["street"], extendedAddress: entry["extended"], city: entry["city"],
          region: entry["region"], postalCode: entry["postal_code"], country: entry["country"], type: entry["type"],
        }.compact
      end

      def body(contact, groups) = { **about(contact), **reach(contact), "memberships" => memberships(contact, groups) }

      def date(value)
        year, month, day = DATE.match(value).captures

        { year: (year.to_i unless year == "-"), month: month.to_i, day: day.to_i }.compact
      end

      def dates(contact) = contact[:dates].map { { date: date(it["value"]), type: it["type"] }.compact }

      def links(contact)
        GooglePerson::HANDLE_LINKS.filter_map do |field, type|
          handle = contact[field]
          { value: profile(field, handle), type: } if handle
        end
      end

      def memberships(contact, groups)
        names = [*contact[:labels].map { groups.fetch(it) }, *(GooglePerson::STARRED if contact[:starred]), MY_CONTACTS]

        names.map { { contactGroupMembership: { contactGroupResourceName: it } } }
      end

      def names(contact)
        parts = NAME_PARTS.to_h { |field, key| [key, contact[field]] }.compact

        parts.empty? ? { unstructuredName: contact[:name] }.compact : parts
      end

      def notes(contact) = values(contact[:notes]).map { it.merge(contentType: "TEXT_PLAIN") }

      def organization(contact)
        { name: contact[:company], title: contact[:job_title], department: contact[:department] }.compact
      end

      def present(entry) = entry.empty? ? [] : [entry]

      def profile(field, handle)
        return "https://bsky.app/profile/#{handle}" if field == :bluesky_handle

        "https://#{LocalMatch.mastodon_profile(handle)}"
      end

      def reach(contact)
        {
          "emailAddresses" => typed(contact[:emails]), "phoneNumbers" => typed(contact[:phones]),
          "addresses" => contact[:addresses].map { address(it) }, "urls" => typed(contact[:websites]) + links(contact),
          "imClients" => typed(contact[:chats], :username, :protocol),
        }
      end

      def touched(fields) = SOURCES.select { |_, sources| sources.intersect?(fields) }.keys

      def typed(entries, value = :value, type = :type)
        entries.map { { value => it["value"], type => it["type"] }.compact }
      end

      def values(value) = value ? [{ value: }] : []
    end
  end
end
