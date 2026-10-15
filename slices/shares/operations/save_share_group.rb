# frozen_string_literal: true

module Shares
  module Operations
    class SaveShareGroup < Blog::Operation
      include Deps[
        contract: "contracts.share_contract",
        group_mutations: "repos.share_group_mutations",
        group_queries: "repos.share_group_queries",
      ]

      def call(id, params)
        group = step found(group_queries.find(id))
        fields = step validated(contract.call(group_form(params)))
        files = step file_fields(group, sent_files(params[:files]))

        step save(group, fields, files)
      end

      private

      def checked_files(group, sent)
        group.share_group_files.filter_map do |file|
          form = sent.fetch(file.id, Blog::Constants::EMPTY_HASH).slice(*editable(file))
          [file.id, contract.call(form)] unless form.empty?
        end.to_h
      end

      def editable(file) = GroupPage::IMAGE.match?(file.content_type) ? %i[alt_text filename] : %i[filename]

      def file_fields(group, sent)
        results = checked_files(group, sent)
        errors = results.reject { |_, result| result.success? }.transform_values { it.errors.to_h }

        errors.empty? ? Success(results.transform_values(&:to_h)) : Failure([:invalid, { files: errors }])
      end

      def group_form(params) = params.slice(:name).merge(code: params[:code])

      def save(group, fields, files)
        transaction { write(group, fields, files) }
        Success(group_queries.find(group.id))
      rescue ROM::SQL::UniqueConstraintError => e
        raise unless group_mutations.violated_constraint(e) == Code::KEY

        Failure([:invalid, { code: [Code::TAKEN] }])
      end

      def sent_files(files)
        Blog::Types::Fields[files].to_h do |id, fields|
          [Blog::Types::IdParam[id.to_s], Blog::Types::Fields[fields]]
        end
      end

      def write(group, fields, files)
        group_mutations.change_code(group.short_code_id, fields[:code])
        group_mutations.name(group.id, fields[:name]) if fields.key?(:name)
        files.each { |file_id, changes| group_mutations.update_file(file_id, **changes) }
      end
    end
  end
end
