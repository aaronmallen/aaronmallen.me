# frozen_string_literal: true

module Blog
  class ScheduledJob < Job
    include Deps["settings", honeybadger: "honeybadger.agent"]

    sidekiq_options retry: false

    def self.check_in_name(*args) = [Hanami.app.inflector.underscore(name.split("::").last), *args].join("_")

    def check_in(*)
      id = settings.honeybadger.fetch(:check_ins, {})[self.class.check_in_name(*)]
      honeybadger.check_in(id) if id
    end
  end
end
