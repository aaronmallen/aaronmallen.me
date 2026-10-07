# frozen_string_literal: true

module Social
  module Operations
    class UpdateWebmentionSettings < Operation
      include Deps[webmention_repo: "repos.webmention_repo"]

      def call(**attrs)
        step changed(attrs)

        webmention_repo.update_settings(**attrs)
      end

      private

      def changed(attrs)
        stored = webmention_repo.settings.to_h.slice(*attrs.keys)

        stored == attrs ? Failure(:unchanged) : Success(attrs)
      end
    end
  end
end
