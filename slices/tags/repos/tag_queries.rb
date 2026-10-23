# frozen_string_literal: true

module Tags
  module Repos
    class TagQueries < Blog::DB::Repo
      include Deps[
        decision_queries: "decisions.repos.decision_queries",
        journal_entry_queries: "record.repos.journal_entry_queries",
        post_tag_queries: "posts.repos.post_tag_queries",
        project_queries: "projects.repos.project_queries",
        task_queries: "tasks.repos.task_queries",
      ]

      KINDS = {
        posts: :post_tag_queries, projects: :project_queries, tasks: :task_queries,
        journal_entries: :journal_entry_queries, decisions: :decision_queries,
      }.freeze

      def all_in(scope, mail: true, project_id: nil)
        found = tags.in_scope(scope, project_id)
        (mail ? found : found.outside_mail).in_name_order.to_a
      end

      def colors_named(scope, names)
        return Blog::Constants::EMPTY_HASH if names.empty?

        tags.in_scope(scope).by_names(names.uniq).to_a.to_h { [it.name, it.color] }
      end

      def count_matching(scope, text, mail: true, project_id: nil) = matching(scope, text, mail, project_id).count

      def find_in(scope, id, project_id: nil) = tags.in_scope(scope, project_id).by_pk(id).one

      def last_tag_of_rules(id) = tags.last_tag_of_rules(id)

      def mail?(scope, id) = tags.in_scope(scope).by_pk(id).on_mail.exist?

      def mail_only?(scope, id) = mail?(scope, id) && !tags.in_scope(scope).by_pk(id).outside_mail.exist?

      def named_in(scope, name) = tags.in_scope(scope).by_names(name).one

      def next_color(scope:, project_id: nil) = tags.next_color(scope:, project_id:)

      def overview(name, page, kind: nil)
        found = tags.global.by_names(name).to_a
        return if found.empty?

        kinds = kind ? [kind.to_sym] : KINDS.keys
        pages = kinds.to_h { [it, public_send(KINDS.fetch(it)).page_by_tag(name, page)] }

        Structs::Overview.new(name:, tags: found, counts: tags.counts_carrying(found.map(&:id)), pages:)
      end

      def page_matching(scope, text, page, mail: true, project_id: nil)
        page.fill(matching(scope, text, mail, project_id).in_name_order.paged(page).to_a)
      end

      def usage(scope:, mail: true)
        by_kind = tags.counts_by_kind(scope)
        by_kind = by_kind.except(:messages) unless mail

        by_kind.values.flat_map(&:keys).uniq.to_h do |id|
          [id, by_kind.filter_map { |kind, counts| [kind, counts[id]] if counts[id] }.to_h]
        end
      end

      private

      def matching(scope, text, mail, project_id)
        found = tags.in_scope(scope, project_id).naming(text)
        mail ? found : found.outside_mail
      end
    end
  end
end
