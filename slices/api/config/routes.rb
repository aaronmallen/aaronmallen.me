# frozen_string_literal: true

module API
  class Routes < Hanami::Routes
    get "/journal_entries", to: "journal_entries.index"
    post "/journal_entries", to: "journal_entries.create"
    get "/journal_entries/:id", to: "journal_entries.show"
    patch "/journal_entries/:id", to: "journal_entries.update"
    delete "/journal_entries/:id", to: "journal_entries.destroy"

    get "/token", to: "tokens.show"
  end
end
