# frozen_string_literal: true

module MCP
  module Tools
    class ListPeople < Base
      description "List the owner's contacts, the people a post or social post mentions as @{key}, as the admin's " \
                  "Contacts tab lists them, each with its ID, key, name and Mastodon and Bluesky handles. With the " \
                  "contacts permission each also carries its private fields: name parts, company, emails, phones, " \
                  "addresses, birthday, notes, labels, starred and the rest, and query also matches them"
      endpoint
    end
  end
end
