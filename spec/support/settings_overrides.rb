# frozen_string_literal: true

module SettingsOverrides
  def lower_throttle_limit(setting, to:)
    settings = Hanami.app["settings"]
    allow(settings).to receive(setting).and_return(settings.public_send(setting).merge(throttle_limit: to))
  end
end

RSpec.configure do |config|
  config.include SettingsOverrides
end
