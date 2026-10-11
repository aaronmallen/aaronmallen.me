# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Edit < Show
        FRESH = { errors: Blog::Constants::EMPTY_HASH, values: nil }.freeze
        PARTS = %i[task timeline forms linking].freeze

        private

        def shown(page) = page.slice(*PARTS).merge(FRESH)
      end
    end
  end
end
