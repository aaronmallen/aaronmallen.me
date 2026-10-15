# frozen_string_literal: true

module LoggedSQL
  def logged_sql
    db = Hanami.app["db.rom"].gateways[:default].connection
    log = StringIO.new
    logger = Logger.new(log)
    db.loggers << logger
    yield
    log.string
  ensure
    db.loggers.delete(logger)
  end
end

RSpec.configure do |config|
  config.include LoggedSQL, type: :request
end
