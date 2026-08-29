# frozen_string_literal: true

module Blog
  module Owner
    module_function

    def full_name = settings[:name]

    def profile_url(network) = Hanami.app.settings.public_send(network)[:profile_url]

    def settings = Hanami.app.settings.owner
  end
end
