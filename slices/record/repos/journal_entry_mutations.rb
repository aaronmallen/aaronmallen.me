# frozen_string_literal: true

module Record
  module Repos
    class JournalEntryMutations < Blog::DB::Repo
      module Rendered
        def self.with_html(attributes)
          attributes.key?(:body) ? attributes.merge(body_html: ::Markdown.to_html(attributes[:body])) : attributes
        end

        def create(attributes = {}, **fields) = super(Rendered.with_html(attributes.merge(fields)))

        def update(id, attributes = {}, **fields) = super(id, Rendered.with_html(attributes.merge(fields)))
      end

      prepend Rendered

      root :journal_entries

      stamped_commands :create, :update
      tagged_by :journal_entry_tags
      commands delete: :by_pk
    end
  end
end
