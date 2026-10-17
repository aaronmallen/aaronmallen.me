# frozen_string_literal: true

RSpec.describe Blog::UI::FieldError do
  Dir[Hanami.app.root.join("slices/*/**/*.rb").to_s].each do |path|
    next unless File.read(path).include?("< Blog::UI::FieldError")

    Object.const_get(Hanami.app.slices[path[%r{slices/(\w+)/}, 1].to_sym].autoloader.cpath_expected_at(path))
  end

  def missing(error, codes)
    view = error.allocate
    i18n = error.slice["i18n"]
    codes.except(*error::UNSHOWN).flat_map do |field, field_codes|
      field_codes.filter_map do |code|
        keys = [error::OVERRIDES.dig(field, code) || ".#{field}.#{code}", "#{Blog::UI::FieldError::CODES}#{code}"]
        ".#{field}.#{code}" if keys.none? { i18n.exists?(view.send(:_resolve_i18n_key, it)) }
      end
    end
  end

  ObjectSpace.each_object(Class).select { it < described_class }.sort_by(&:name).each do |error|
    it "names the contracts #{error} words" do
      expect(error.const_defined?(:CONTRACTS, false)).to be(true)
    end

    next unless error.const_defined?(:CONTRACTS, false)

    error::CONTRACTS.each do |contract|
      it "words every code #{contract} can return in #{error}" do
        expect(missing(error, ContractCodes.call(contract))).to be_empty
      end
    end
  end

  it "words every code connecting a service can return" do
    fields = Services::Slice["repos.definition_queries"].all.flat_map(&:fields).uniq
    codes = fields.to_h { [it.to_sym, [Admin::Operations::ConnectService::BLANK]] }

    expect(missing(Admin::UI::Components::Services::FieldError, codes)).to be_empty
  end
end
