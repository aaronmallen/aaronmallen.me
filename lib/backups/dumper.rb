# frozen_string_literal: true

require "open3"

module Backups
  class Dumper
    class Error < Backups::Error; end

    COMMAND = "pg_dump"

    def initialize(database:)
      @database = database
    end

    def call(path)
      _, error, status = Open3.capture3(environment, COMMAND, "--format=custom", "--no-password", "--file=#{path}")
      raise Error, error.strip unless status.success?

      path
    rescue SystemCallError => e
      raise Error, e.message
    end

    def inspect = "#<#{self.class.name} database=#{database[:name]}>"

    private

    attr_reader :database

    def environment
      {
        "PGDATABASE" => database[:name],
        "PGHOST" => database[:host],
        "PGPASSWORD" => database[:password],
        "PGPORT" => database[:port]&.to_s,
        "PGUSER" => database[:user],
      }
    end
  end
end
