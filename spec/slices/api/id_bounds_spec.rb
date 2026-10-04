# frozen_string_literal: true

RSpec.describe "API ID bounds", type: :app do
  def largest = Blog::Constants::INTEGER_MAX

  describe "bulk endpoints handed an ID the schema let through" do
    %w[complete_tasks delete_posts mark_messages_read approve_webmentions].each do |name|
      it "#{name} refuses it with a list of reasons under ids" do
        refusal = API::Slice["endpoints.#{name}"].handle(ids: [2**31]).failure

        expect([refusal.error, refusal.errors]).to eq([:invalid, { ids: ["must be less than #{largest + 1}"] }])
      end
    end
  end

  describe "ID schemas" do
    def ids(schema, parent = nil)
      schema.flat_map do |key, value|
        next [] unless value.is_a?(Hash)

        id = key.to_s.end_with?("id") || (key == :items && parent.to_s.end_with?("ids"))
        (id ? [value] : []) + ids(value, key)
      end
    end

    let(:schemas) do
      (API::Endpoints.constants + MCP::Tools.constants).filter_map do |name|
        owner = API::Endpoints.const_defined?(name) ? API::Endpoints : MCP::Tools
        found = owner.const_get(name)
        found.const_get(:SCHEMA) if found.is_a?(Class) && found.const_defined?(:SCHEMA)
      end
    end

    it "bounds every ID from 1 to the largest" do
      bounds = schemas.flat_map { ids(it) }.map { it.slice(:minimum, :maximum) }.uniq

      expect(bounds).to eq([{ minimum: 1, maximum: largest }])
    end
  end
end
