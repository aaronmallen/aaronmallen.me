# frozen_string_literal: true

module Spec
  module AdminI18n
    def admin_t(...) = Admin::Slice["i18n"].t(...)
  end
end

RSpec.configure do |config|
  config.include Spec::AdminI18n, type: :request
  config.include Spec::AdminI18n, :browser
end
