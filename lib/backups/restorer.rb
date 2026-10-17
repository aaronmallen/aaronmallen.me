# frozen_string_literal: true

require "open3"
require "securerandom"
require "sequel"

module Backups
  class Restorer
    class Error < Backups::Error; end

    TABLES = %w[schema_migrations posts tasks].freeze
    SQL = Sequel.mock(host: "postgres")
    QUERY = SQL.select(*TABLES.map { |table| SQL[table.to_sym].select { count.function.* } }).sql.freeze

    def initialize(database:)
      @database = database
    end

    def call(path)
      scratch = "#{database[:name]}_restore_#{SecureRandom.hex(4)}"
      run("createdb", scratch)
      begin
        run("pg_restore", "--no-owner", "--no-privileges", "--exit-on-error", "--dbname=#{scratch}",
            File.expand_path(path))
        check(run("psql", "--no-psqlrc", "--tuples-only", "--no-align", "--dbname=#{scratch}", "--command=#{QUERY}"))
      ensure
        run("dropdb", "--if-exists", scratch)
      end
    end

    def inspect = "#<#{self.class.name} database=#{database[:name]}>"

    private

    attr_reader :database

    def check(output)
      counts = TABLES.zip(output.strip.split("|").map(&:to_i)).to_h
      empty = counts.select { |_, count| count.zero? }.keys
      raise Error, "#{empty.join(', ')} came back empty" if empty.any?

      counts
    end

    def environment
      {
        "PGDATABASE" => nil,
        "PGHOST" => database[:host],
        "PGPASSWORD" => database[:password],
        "PGPORT" => database[:port]&.to_s,
        "PGUSER" => database[:user],
      }
    end

    def run(command, *)
      output, error, status = Open3.capture3(environment, command, "--no-password", *)
      raise Error, error.strip unless status.success?

      output
    rescue SystemCallError => e
      raise Error, e.message
    end
  end
end
