# frozen_string_literal: true

RSpec.describe Blog::Types do
  describe "Normalized::LabelTag" do
    let(:label_tag) { described_class::Normalized::LabelTag }

    it "turns a label into a tag name", :aggregate_failures do
      expect(label_tag["Bug Fix"]).to eq("bug-fix")
      expect(label_tag["BugFix"]).to eq("bug-fix")
      expect(label_tag["bug_fix"]).to eq("bug-fix")
      expect(label_tag["area/api"]).to eq("area-api")
      expect(label_tag["Needs Review!"]).to eq("needs-review")
    end

    it "keeps the app's acronyms whole" do
      expect(label_tag["GitHub"]).to eq("github")
    end

    it "turns a label with no valid form into nothing", :aggregate_failures do
      expect(label_tag.call("!!!") { nil }).to be_nil
      expect(label_tag.call("") { nil }).to be_nil
    end
  end
end
