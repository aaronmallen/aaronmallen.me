# frozen_string_literal: true

module SettingsOverrides
  def lower_page_size(scope, to:) = override_setting(:page_size, scope, to:)

  def lower_throttle_limit(setting, to:) = override_setting(setting, :throttle_limit, to:)

  def override_setting(group, key, to:)
    settings = Hanami.app["settings"]
    allow(settings).to receive(group).and_return(settings.public_send(group).merge(key => to))
  end
end

RSpec.configure do |config|
  config.include SettingsOverrides
end
