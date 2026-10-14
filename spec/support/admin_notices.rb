# frozen_string_literal: true

module Spec
  module AdminNotices
    WAIT_SECONDS = 0.5

    def admin_notice(&)
      url = Blog::Providers::DBProvider.database_url(Hanami.app["settings"].database)
      table = nil
      Sequel.connect(url, keep_reference: false) do |listener|
        options = { after_listen: ->(_) { yield }, timeout: WAIT_SECONDS }
        listener.listen(Admin::Live::Hub::CHANNEL, **options) { |*, payload| table = payload }
      end
      table
    end
  end
end

RSpec.configure do |config|
  config.include Spec::AdminNotices, :commits
end
