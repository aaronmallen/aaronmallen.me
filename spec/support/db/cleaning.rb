# frozen_string_literal: true

require "capybara"
require "database_cleaner/sequel"

RSpec.configure do |config|
  databases = nil
  all_databases = lambda {
    databases ||= Hanami.app.with_slices.each_with_object([]) do |slice, dbs|
      next unless slice.key?("db.rom")

      dbs.concat slice["db.rom"].gateways.values.map(&:connection)
    end.uniq
  }

  config.before :suite do
    all_databases.call.each do |db|
      name = db.opts[:database]
      raise "#{name} does not end in _test, so the suite will not empty it" unless name.end_with?("_test")

      DatabaseCleaner[:sequel, db: db].clean_with :truncation, except: ["schema_migrations"]
    end
  end

  config.prepend_before do |example|
    strategy = example.metadata[:js] || example.metadata[:commits] ? :truncation : :transaction

    all_databases.call.each do |db|
      DatabaseCleaner[:sequel, db: db].strategy = strategy
      DatabaseCleaner[:sequel, db: db].start
    end
  end

  config.after do |example|
    Capybara.reset_sessions! if example.metadata[:js]
  ensure
    all_databases.call.each do |db|
      DatabaseCleaner[:sequel, db: db].clean
    end
  end
end
