# frozen_string_literal: true

module Social
  module Operations
    class TagLinks
      include Deps["settings"]

      def call(body, network)
        Links.new(body).map { settings.owns?(it) ? ::Analytics::Ref.tag(it, network) : it }
      end
    end
  end
end
