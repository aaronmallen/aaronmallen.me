# frozen_string_literal: true

require "hanami/cli"
require "hanami/cli/commands/app/db/utils/postgres"
require "shellwords"
require "uri"

module Blog
  module Extensions
    module Hanami
      module CLI
        module DB
          module Postgres
            module Extension
              PERCENT_ENCODED_VARS = %w[PGUSER PGPASSWORD].freeze

              def exec_drop_command
                result = super
                return result unless result == true || result.successful?
                return result unless exists?

                ::Hanami::CLI::SystemCall::Result.new(
                  exit_code: 1, out: "", err: "database #{name} is still there, so nothing was dropped",
                )
              end

              def exists?
                sql = "SELECT 1 FROM pg_database WHERE datname = '#{name.gsub("'", "''")}'"
                command = "psql -t -A --no-psqlrc -c #{Shellwords.escape(sql)} template1"
                result = system_call.call(command, env: cli_env_vars)
                raise ::Hanami::CLI::DatabaseExistenceCheckError, result.err unless result.successful?

                result.out == "1"
              end

              private

              def cli_env_vars
                vars = super
                vars.merge(vars.slice(*PERCENT_ENCODED_VARS).transform_values { URI.decode_uri_component(it) })
              end
            end
          end
        end
      end
    end
  end
end

Hanami::CLI::Commands::App::DB::Utils::Postgres.prepend(Blog::Extensions::Hanami::CLI::DB::Postgres::Extension)
