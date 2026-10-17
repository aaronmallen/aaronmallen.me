# frozen_string_literal: true

module Shares
  module Operations
    class SaveShortLink < Blog::Operation
      include Deps[
        "operations.change_code", "operations.retarget_short_link", "operations.queue_title_fetch",
        "operations.set_short_link_title",
        short_link_mutations: "repos.short_link_mutations",
      ]

      def call(id, params)
        transaction do
          step change_code.call(step(retarget_short_link.call(id, params)), params)
          link = step set_short_link_title.call(id, params)
          short_link_mutations.after_commit { queue_title_fetch.call(id) } unless link.title
          link
        end
      end
    end
  end
end
