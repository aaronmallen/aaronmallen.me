# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class GitHubCallback < ServiceCallback
        NAME = "GitHub"
        PROVIDER = Blog::Types::ServiceProvider["github"]

        include Deps[connect_github: "operations.connect_github"]

        private

        def connect(started, code)
          connect_github.call(code:, code_verifier: started.fetch("verifier"), redirect_uri:)
        end
      end
    end
  end
end
