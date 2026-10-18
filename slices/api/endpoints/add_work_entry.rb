# frozen_string_literal: true

module API
  module Endpoints
    class AddWorkEntry < Endpoint
      COMPLAINTS = {
        from_year: {
          Blog::Contract::BLANK => "add the year this started",
          Blog::Contract::FORMAT => "use a four digit year, as 2018",
        },
        org: { Blog::Contract::BLANK => "name the organization" },
        role: { Blog::Contract::BLANK => "name the role" },
        to_year: {
          "before_from" => "the end year falls before the start year",
          Blog::Contract::FORMAT => "use a four digit year, as 2021",
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

      REPLY = Serializers::WorkEntry.reference

      include Deps[add_work_entry: "projects.operations.add_work_entry"]

      def handle(org:, role:, from_year:, blurb: nil, to_year: nil)
        case add_work_entry.call({ blurb:, from_year: from_year.to_s, org:, role:, to_year: to_year&.to_s })
          in Success(entry) then Success(serialized(Serializers::WorkEntry, entry))
          in Failure[:invalid, errors] then rejected(errors, COMPLAINTS)
          in unmatched then unhandled(unmatched, "could not add the role")
        end
      end
    end
  end
end
