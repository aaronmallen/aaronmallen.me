# frozen_string_literal: true

module Tasks
  module Repos
    class TaskLabelQueries < Blog::DB::Repo
      LABEL = /\A#?(?:(?<key>[A-Za-z][A-Za-z0-9]*)-)?(?<number>\d{1,9})\z/

      include Deps[project_queries: "projects.repos.project_queries"]

      def ids_labelled(text) = LABEL.match?(text.to_s) ? labelled_as(tasks, text).pluck(:id) : []

      def labelled_as(found, text)
        key, number = text.match(LABEL)&.captures
        project_id = project_queries.id_by_key(key) if key
        return found.none if number.nil? || (key && project_id.nil?)

        found.where({ number: number.to_i, project_id: }.compact)
      end

      def labels(ids) = tasks.where(id: ids).labelled.to_a.to_h { [it.id, it.label] }

      def linkable_matching(_relation, text, limit)
        ids = ids_labelled(text)
        found = tasks.matching(text, ids).limit(limit).linkable

        ids.empty? ? found : found.order_prepend(Sequel.case({ { id: ids } => 0 }, 1))
      end

      def terms(projects: [], **search)
        search = { **search, label_ids: ids_labelled(search[:text]) }
        projects.empty? ? search : { **search, project_ids: project_queries.ids_by_slug(projects) }
      end
    end
  end
end
