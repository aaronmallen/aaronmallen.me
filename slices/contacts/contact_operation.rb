# frozen_string_literal: true

module Contacts
  class ContactOperation < Blog::Operation
    PAGE_SIZE = 1000
    PROVIDER = Blog::Types::ServiceProvider["google"]

    include Deps[google: "google.client", connection_queries: "services.repos.connection_queries"]

    private

    def account(connection) = Google::Account.new(google, connection.account_id)

    def api_url(path, **params)
      url = google.url(:people, path)

      params.empty? ? url : "#{url}?#{URI.encode_www_form(params)}"
    end

    def connection(person)
      return unless google.configured?
      return connection_queries.by_id(person.google_connection_id) if person&.google_connection_id

      connection_queries.for(PROVIDER).find(&:saves_contacts)
    end

    def groups(account)
      rows = account.pages(api_url("contactGroups"), rows: "contactGroups", pageSize: PAGE_SIZE).fetch("contactGroups")

      Helpers::GooglePerson.groups(rows)
    end

    def written
      yield
    rescue Google::Error => e
      Failure([:google_failed, e.message])
    end
  end
end
