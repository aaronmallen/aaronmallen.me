# frozen_string_literal: true

RSpec.describe Blog::Extensions do
  describe ".apply" do
    let(:extension) { Module.new }
    let(:target) { Class.new }

    def apply(version) = described_class.apply(target, extension, gem: "rack", version:, reason: "a bug", upstream: nil)

    it "prepends the extension when the gem is at the version it was written against" do
      apply(Gem.loaded_specs.fetch("rack").version.to_s)

      expect(target.ancestors.first).to eq(extension)
    end

    it "raises naming the file to check when the gem is at another version", :aggregate_failures do
      expect { apply("0.0.1") }.to raise_error(described_class::VersionMismatch, /#{Regexp.escape(__FILE__)}.*a bug/)
      expect(target.ancestors).not_to include(extension)
    end
  end
end
