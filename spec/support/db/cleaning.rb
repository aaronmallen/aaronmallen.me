# frozen_string_literal: true

require "capybara"
require "database_cleaner/sequel"
require_relative "locks"

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
      unless name.match?(/_test(_\d+)?\z/)
        raise "#{name} does not end in _test or _test_<id>, so the suite will not empty it"
      end

      Spec::DB::Locks.hold_suite(db)
      Spec::DB::Locks.within_timeout(db) do
        DatabaseCleaner[:sequel, db: db].clean_with :truncation, except: ["schema_migrations"]
      end
    end
  end

  truncating = ->(example) { example.metadata[:js] || example.metadata[:commits] }

  config.prepend_before do |example|
    strategy = truncating.call(example) ? :truncation : :transaction

    all_databases.call.each do |db|
      DatabaseCleaner[:sequel, db: db].strategy = strategy
      DatabaseCleaner[:sequel, db: db].start
    end
  end

  config.after do |example|
    Capybara.reset_sessions! if example.metadata[:js]
  ensure
    all_databases.call.each do |db|
      cleaner = DatabaseCleaner[:sequel, db: db]
      truncating.call(example) ? Spec::DB::Locks.within_timeout(db) { cleaner.clean } : cleaner.clean
    end
  end
end
