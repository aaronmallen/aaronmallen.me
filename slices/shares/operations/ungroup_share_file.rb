# frozen_string_literal: true

module Shares
  module Operations
    class UngroupShareFile < Blog::Operation
      include Deps[
        group_mutations: "repos.share_group_mutations",
        group_queries: "repos.share_group_queries",
        share_queries: "repos.share_queries",
        short_code_queries: "repos.short_code_queries",
      ]

      def call(id, file_id)
        group = step found(group_queries.find(id))
        file = step found(group.share_group_files.find { it.id == file_id })

        transaction { ungroup(group, file) }
        share_queries.find(file.id)
      end

      private

      def leave(file_id, attempts = Code::ATTEMPTS)
        group_mutations.leave(file_id, code: short_code_queries.free_code)
      rescue ROM::SQL::UniqueConstraintError => e
        raise unless group_mutations.violated_constraint(e) == Code::KEY && attempts > 1

        leave(file_id, attempts - 1)
      end

      def ungroup(group, file)
        leave(file.id)
        group_mutations.delete(group.short_code_id) if group.share_group_files.one?
      end
    end
  end
end
