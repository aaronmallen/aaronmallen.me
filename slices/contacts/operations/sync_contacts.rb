# frozen_string_literal: true

module Contacts
  module Operations
    class SyncContacts < Blog::Operation
      PAGE_SIZE = 1000
      SCOPE = "https://www.googleapis.com/auth/contacts"

      include Deps[
        google: "google.client", connection_queries: "services.repos.connection_queries",
        person_mutations: "repos.person_mutations", person_queries: "repos.person_queries",
      ]

      def call = step synced

      private

      def contacts(account, token)
        found = account.pages(
          "#{Helpers::GooglePerson::API}/people/me/connections",
          rows: "connections", personFields: fields, pageSize: PAGE_SIZE, requestSyncToken: true,
          **({ syncToken: token } if token),
        )

        { full: token.nil?, sync_token: found["nextSyncToken"], connections: found.fetch("connections") }
      rescue Google::Error
        raise if token.nil?

        contacts(account, nil)
      end

      def fields
        %w[
          addresses biographies birthdays emailAddresses events fileAses imClients memberships names nicknames
          organizations phoneNumbers relations urls userDefined
        ].join(",")
      end

      def groups(account)
        rows = account.pages(
          "#{Helpers::GooglePerson::API}/contactGroups", rows: "contactGroups", pageSize: PAGE_SIZE,
        ).fetch("contactGroups")

        Helpers::GooglePerson.groups(rows)
      end

      def pulled(account, token)
        found = contacts(account, token)
        groups = groups(account)
        gone, kept = found.delete(:connections).partition { it.dig("metadata", "deleted") }
        people, unnamed = kept.map { Helpers::GooglePerson.row(it, groups) }.partition { it[:name] || it[:company] }

        { **found, people:, gone: (gone.map { Helpers::GooglePerson.google_id(it) } + unnamed.map { it[:google_id] }) }
      end

      def sync(account, connection_id, token)
        Success(person_mutations.store_google(connection_id, { **pulled(account, token), first: token.nil? }))
      rescue Google::Error => e
        Failure([:google_contacts_failed, e.message])
      end

      def synced
        return Success(0) unless google.configured?

        client = google.loaded
        tokens = person_queries.sync_tokens
        results = syncing(client).map { sync(Google::Account.new(client, it.account_id), it.id, tokens[it.id]) }
        results.find(&:failure?) || Success(results.sum(&:value!))
      end

      def syncing(client)
        holders = client.holders(SCOPE)
        connections = connection_queries.for(Blog::Types::ServiceProvider["google"])

        connections.select { it.sync_contacts && holders.include?(it.account_id) }
      end
    end
  end
end
