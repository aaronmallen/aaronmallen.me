# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class LinkedInCallback < ServiceCallback
        NAME = "LinkedIn"
        PROVIDER = Blog::Types::ServiceProvider["linkedin"]

        include Deps[connect_linkedin: "operations.connect_linkedin"]

        private

        def connect(_started, code) = connect_linkedin.call(code:, redirect_uri:)
      end
    end
  end
end
