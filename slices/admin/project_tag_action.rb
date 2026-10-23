# auto_register: false
# frozen_string_literal: true

module Admin
  class ProjectTagAction < Action
    PROJECT = Blog::Types::TagScope["project"]
    REFUSALS = [Blog::Contract::BLANK, Tags::Operations::SaveTag::TAKEN].freeze
    TOASTS = "projects_page.toasts.tags"

    include Deps[project_queries: "projects.repos.project_queries"]

    private

    def project_id(request)
      id = record_id(request)
      project_queries.by_id(id) ? id : halt(:not_found)
    end

    def refusal(errors) = errors.fetch(:name, Blog::Constants::EMPTY_ARRAY).find { REFUSALS.include?(it) } || "format"

    def settled(request, response, result, done)
      case result
        in Success(_) then toast(response, "#{TOASTS}.#{done}")
        in Failure[:invalid, errors] then toast(response, "#{TOASTS}.#{refusal(errors)}")
        in Failure[:last_tag_of_rules, patterns]
          toast(response, "#{TOASTS}.kept", count: patterns.size, rules: patterns.join(", "))
        in Failure(:not_found) then halt :not_found
      end

      response.redirect_to(routes.path(:admin_project, id: record_id(request), tags: "open"))
    end
  end
end
