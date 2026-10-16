# frozen_string_literal: true

module Tasks
  module Repos
    class TaskLabelQueries < Blog::DB::Repo
      LABEL = /\A#?(?:(?<key>[A-Za-z][A-Za-z0-9]*)-)?(?<number>\d{1,9})\z/

      include Deps[project_queries: "projects.repos.project_queries"]

      def labelled_as(found, text)
        key, number = text.match(LABEL)&.captures
        project_id = project_queries.id_by_key(key) if key
        return found.none if number.nil? || (key && project_id.nil?)

        found.where({ number: number.to_i, project_id: }.compact)
      end

      def linkable(relation, text: nil, limit: nil, **)
        found = super
        return found unless text

        rows = (labelled_as(tasks, text).limit(limit).linkable + found).uniq(&:id)
        limit ? rows.first(limit) : rows
      end
    end
  end
end
