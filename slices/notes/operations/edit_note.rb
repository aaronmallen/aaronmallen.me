# frozen_string_literal: true

module Notes
  module Operations
    class EditNote < Blog::Operation
      CHANGED = "changed"
      REFUSALS = { "notes_title_index" => [:title, "taken"] }.freeze
      TEXT = %i[title body].freeze

      include Deps[
        contract: "contracts.note_contract",
        note_mutations: "repos.note_mutations",
        note_queries: "repos.note_queries",
      ]

      def call(id, params, agent: false)
        fields = step validated(contract.call(params.slice(:title, :body, :tags).merge(version: params[:version])))
        step constrained(note_mutations, REFUSALS) { Success(transaction { edit(id, agent, **fields) }) }

        note_queries.by_id(id)
      end

      private

      def current(note, version)
        return Failure(:not_found) unless note

        note.version == version ? Success(note) : invalid(:version, CHANGED)
      end

      def edit(id, agent, version:, tags: nil, **fields)
        note = step current(note_mutations.by_id_for_update(id), version)
        note_mutations.update(id, fields.merge(writer(agent, fields)))
        note_mutations.replace_tags(id, tags) if tags
        note_mutations.store_links(id, fields[:body]) if fields.key?(:body)
        note_mutations.relink(note.title, fields[:title], agent:) if fields.fetch(:title, note.title) != note.title
      end

      def writer(agent, fields)
        return { written_by_agent: true } if agent && fields.keys.intersect?(TEXT)

        TEXT.all? { fields.key?(it) } ? { written_by_agent: agent } : {}
      end
    end
  end
end
