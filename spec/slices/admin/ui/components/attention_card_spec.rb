# frozen_string_literal: true

RSpec.describe Admin::UI::Components::AttentionCard do
  it "names a renderer for every attention kind" do
    expect(described_class::KINDS.keys).to match_array(Blog::Types::AttentionKind.values)
  end
end
