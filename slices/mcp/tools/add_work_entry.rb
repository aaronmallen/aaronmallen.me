# frozen_string_literal: true

module MCP
  module Tools
    class AddWorkEntry < Base
      UNSAVED = "could not add the role"

      MESSAGES = {
        from_year: { "blank" => "add the year this started", "format" => "use a four digit year, as 2018" },
        org: { "blank" => "name the organization" },
        role: { "blank" => "name the role" },
        to_year: {
          "before_from" => "the end year falls before the start year",
          "format" => "use a four digit year, as 2021",
        },
      }.freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          blurb: { type: "string", description: "one line on what the work was" },
          from_year: { type: "integer", description: "the year it started" },
          org: { type: "string", description: "the organization" },
          role: { type: "string" },
          to_year: { type: "integer", description: "the year it ended; leave it out for a role still held" },
        },
        required: %w[org role from_year],
      }.freeze

      description "Add a role to the end of the work list on /projects"
      input_schema(SCHEMA)
      scope Blog::Types::OAuthScope["write"]

      class << self
        def call(org:, role:, from_year:, server_context:, blurb: nil, to_year: nil)
          params = { blurb:, from_year: from_year.to_s, org:, role:, to_year: to_year&.to_s }

          case dep(:add_work_entry, server_context).call(params)
            in Success(entry) then answer(ListWorkEntries.summary(entry))
            in Failure[:invalid, errors] then invalid(errors, MESSAGES)
            else refuse(UNSAVED)
          end
        end
      end
    end
  end
end
