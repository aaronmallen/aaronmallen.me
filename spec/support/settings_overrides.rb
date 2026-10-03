# frozen_string_literal: true

module SettingsOverrides
  def change_attention_limit(limit, to:)
    settings = Hanami.app["settings"]
    allow(settings).to receive(:attention).and_return(settings.attention.merge(limit => to))
  end

  def lower_page_size(scope, to:)
    settings = Hanami.app["settings"]
    allow(settings).to receive(:page_size).and_return(settings.page_size.merge(scope => to))
  end

  def lower_throttle_limit(setting, to:)
    settings = Hanami.app["settings"]
    allow(settings).to receive(setting).and_return(settings.public_send(setting).merge(throttle_limit: to))
  end
end

RSpec.configure do |config|
  config.include SettingsOverrides
end
