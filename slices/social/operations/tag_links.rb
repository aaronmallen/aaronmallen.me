# frozen_string_literal: true

module Social
  module Operations
    class TagLinks
      include Deps["settings", tag_ref: "analytics.operations.tag_ref"]

      def call(body, network)
        Links.new(body).map { settings.owns?(it) ? tag_ref.call(it, network) : it }
      end
    end
  end
end
