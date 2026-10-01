# frozen_string_literal: true

module Projects
  module Operations
    class SaveProject < Blog::Operation
      include Deps[contract: "contracts.project_contract", project_repo: "repos.project_repo"]

      CONSTRAINTS = {
        "projects_archived_order_check" => [:started_on, "after_archived"],
        "projects_repo_index" => [:repo, "taken"],
      }.freeze
      FIELDS = %i[name og_image_url repo started_on status tagline url].freeze

      def call(params, id: nil, now: Time.now)
        attributes = step validate(params, now)
        step persist(id, attributes)
      end

      private

      def create_or_update(project, attributes)
        fields = attributes.except(:tags)
        saved = project ? project_repo.update(project.id, fields) : project_repo.append(**fields)
        project_repo.replace_tags(saved.id, attributes.fetch(:tags))

        project_repo.by_id(saved.id)
      end

      def created(attributes)
        status = attributes[:status] || Blog::Types::ProjectLiveStatus["active"]

        create_or_update(nil, attributes.merge(status:))
      end

      def derive(repo, url)
        named = Blog::Types::Normalized::Repo.call(repo) { repo.to_s.strip }
        address = Blog::Types::Normalized::Url.call(url) { url.to_s.strip }
        return [named, github_url(named)] if address.empty?
        return [repo_from(address), address] if named.empty?

        [named, address]
      end

      def find(id)
        return Success(nil) unless id

        project = project_repo.by_id(id)
        project ? Success(project) : Failure(:not_found)
      end

      def form(params)
        given = FIELDS.to_h { [it, params[it]] }
        repo, url = derive(*given.values_at(:repo, :url))

        given.merge(repo:, url:, featured: params[:featured], tags: params[:tags])
      end

      def github_url(repo)
        named = Blog::Types::Normalized::Repo.call(repo) { nil }

        named ? format(Blog::Constants::GITHUB_REPO_URL, named) : Blog::Constants::EMPTY_STRING
      end

      def persist(id, attributes)
        transaction { save(step(find(id)), attributes) }
      rescue ROM::SQL::UniqueConstraintError, ROM::SQL::CheckConstraintError => e
        field, code = CONSTRAINTS[project_repo.violated_constraint(e)]
        raise unless field

        Failure([:invalid, { field => [code] }])
      end

      def repo_from(url) = Blog::Types::Normalized::GithubRepo.call(url) { Blog::Constants::EMPTY_STRING }

      def save(project, attributes)
        return Success(created(attributes)) unless project

        Success(create_or_update(project, updated(project, attributes)))
      end

      def updated(project, attributes)
        keep_status = project.archived? || attributes[:status].nil?

        keep_status ? attributes.except(:status) : attributes
      end

      def validate(params, now) = validated(contract.call(form(params), today: Blog::TimeZone.today(now)))
    end
  end
end
