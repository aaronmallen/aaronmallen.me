# frozen_string_literal: true

module Social
  module Operations
    class TagLinks
      include Deps["settings", scan_links: "operations.scan_links", tag_ref: "analytics.operations.tag_ref"]

      def call(body, network)
        scan_links.map(body) { settings.owns?(it) ? tag_ref.call(it, network) : it }
      end
    end
  end
end
