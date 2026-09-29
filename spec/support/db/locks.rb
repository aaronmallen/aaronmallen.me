# frozen_string_literal: true

require "sequel"

module Spec
  module DB
    module Locks
      LOCK_TIMEOUT = "30s"
      SUITE_KEY = "rspec suite"

      class << self
        def hold_suite(db)
          holder = Sequel.connect(db.opts.merge(keep_reference: false, max_connections: 1))
          return holders << holder if holder.get(Sequel.function(:pg_try_advisory_lock, suite_key))

          holder.disconnect
          raise "another test run holds #{db.opts[:database]}; let it finish or stop it, then run the suite again"
        end

        def within_timeout(db)
          db.synchronize do
            db.run("SET lock_timeout = '#{LOCK_TIMEOUT}'")
            yield
          ensure
            db.run("RESET lock_timeout")
          end
        rescue Sequel::DatabaseLockTimeout
          raise "#{db.opts[:database]} waited #{LOCK_TIMEOUT} on a lock another session holds:\n#{open_sessions(db)}"
        end

        private

        def holders = @holders ||= []

        def open_sessions(db)
          db[:pg_stat_activity]
            .where(datname: Sequel.function(:current_database))
            .exclude(pid: Sequel.function(:pg_backend_pid))
            .exclude(xact_start: nil)
            .select_map(%i[pid application_name state query])
            .map { "  #{it.join(' | ')}" }
            .join("\n")
        end

        def suite_key = Sequel.function(:hashtext, SUITE_KEY)
      end
    end
  end
end
