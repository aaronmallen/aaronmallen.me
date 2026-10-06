# frozen_string_literal: true

require "rack/test"

module MissingTranslations
  include Rack::Test::Methods

  MARK = "translation_missing"

  def build_rack_test_session(name)
    super.tap do |session|
      session.after_request do
        next unless session.last_response.body.include?(MARK)

        missing_translations << "#{session.last_request.request_method} #{session.last_request.fullpath}"
      end
    end
  end

  def missing_translations = @missing_translations ||= []
end

RSpec.configure do |config|
  config.include MissingTranslations, type: :request

  config.after(type: :request) do
    expect(missing_translations).to be_empty, "a missing translation renders on:\n#{missing_translations.join("\n")}"
  end
end
