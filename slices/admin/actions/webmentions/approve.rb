# frozen_string_literal: true

module Admin
  module Actions
    module Webmentions
      class Approve < Action
        VERDICT = Blog::Types::WebmentionStatus["approved"]

        include Deps[moderate_webmention: "social.operations.moderate_webmention"]

        include Moderation
      end
    end
  end
end
