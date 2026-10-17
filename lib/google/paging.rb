# frozen_string_literal: true

module Google
  module Paging
    MAX_PAGES = 100

    def pages(url, rows:, account:, token_param: :pageToken, **params)
      found = []
      page = nil
      seen = Set[nil, ""]

      MAX_PAGES.times do
        page = get(url, account:, **params, **({ token_param => page["nextPageToken"] } if page))
        found.concat(page.fetch(rows, []))
        break unless seen.add?(page["nextPageToken"])
      end

      page.merge(rows => found)
    end
  end
end
