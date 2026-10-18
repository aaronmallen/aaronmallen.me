# frozen_string_literal: true

RSpec.describe Mail::Relations::MailThreads do
  it "names a scope for every mail folder" do
    expect(described_class::FOLDERS.keys).to match_array(Blog::Types::MailFolder.values)
  end
end
