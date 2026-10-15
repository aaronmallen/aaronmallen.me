# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class GoogleCallback < ServiceCallback
        NAME = "Google"
        PROVIDER = Blog::Types::ServiceProvider["google"]

        include Deps[connect_google: "operations.connect_google"]

        private

        def connect(started, code)
          connect_google.call(
            code:, code_verifier: started.fetch("verifier"), redirect_uri:, connection: started["connection"],
          )
        end
      end
    end
  end
end
