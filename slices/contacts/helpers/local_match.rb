# frozen_string_literal: true

module Contacts
  module Helpers
    module LocalMatch
      module_function

      def mastodon_profile(handle)
        user, instance = handle.delete_prefix("@").split("@", 2)

        "#{instance}/@#{user}"
      end

      def pairs(people, rows)
        people = people.to_h { [it, person_keys(it)] }
        rows = rows.to_h { [it, row_keys(it)] }

        %i[email profile name].flat_map { pairs_by(it, people, rows) }
      end

      def pairs_by(kind, people, rows)
        rows.to_a.filter_map do |row, keys|
          person, = people.find { |_, found| found[kind].intersect?(keys[kind]) }
          next unless person

          people.delete(person)
          rows.delete(row)
          [person, row]
        end
      end

      def person_keys(person)
        bluesky = [person.bluesky_handle, person.bluesky_did].compact.map { "bsky.app/profile/#{it}" }
        profiles = [*person.mastodon_handle&.then { mastodon_profile(it) }, *bluesky]

        {
          email: person.emails.to_set { it["value"].downcase }, name: Set[person.name].delete(nil),
          profile: profiles.to_set { profile(it) },
        }
      end

      def profile(url) = url.downcase.delete_prefix("https://").delete_prefix("http://").chomp("/")

      def row_keys(row)
        {
          email: row[:emails].to_set { it[:value].downcase }, name: Set[row[:name]].delete(nil),
          profile: row[:websites].to_set { profile(it[:value]) },
        }
      end
    end
  end
end
