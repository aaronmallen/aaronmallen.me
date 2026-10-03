# frozen_string_literal: true

module Social
  class LinkTagger
    def initialize(settings)
      @settings = settings
    end

    def call(body, network)
      Links.new(body).map { @settings.owns?(it) ? ::Analytics::Ref.tag(it, network) : it }
    end
  end
end
