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
        fields = step validated(contract.call(code: params[:code]))
        alt_texts = step alt_texts(group, sent_alt_texts(params[:files]))

        step save(group, fields[:code], alt_texts)
      end

      private

      def alt_texts(group, sent)
        results = checked_images(group, sent)
        errors = results.reject { |_, result| result.success? }.transform_values { it.errors.to_h }

        errors.empty? ? Success(results.transform_values { it[:alt_text] }) : Failure([:invalid, { files: errors }])
      end

      def checked_images(group, sent)
        images = group.share_group_files.select { GroupPage::IMAGE.match?(it.content_type) && sent.key?(it.id) }
        images.to_h { [it.id, contract.call(alt_text: sent[it.id])] }
      end

      def save(group, code, alt_texts)
        transaction do
          group_mutations.change_code(group.short_code_id, code)
          alt_texts.each { |file_id, alt_text| group_mutations.set_alt_text(file_id, alt_text) }
        end
        Success(group_queries.find(group.id))
      rescue ROM::SQL::UniqueConstraintError => e
        raise unless group_mutations.violated_constraint(e) == Code::KEY

        Failure([:invalid, { code: [Code::TAKEN] }])
      end

      def sent_alt_texts(files)
        Blog::Types::Fields[files].to_h do |id, fields|
          [Blog::Types::IdParam[id.to_s], Blog::Types::Fields[fields][:alt_text]]
        end
      end
    end
  end
end
