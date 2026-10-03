# frozen_string_literal: true

RSpec.describe SavedViews::Queries::All do
  def all(**) = SavedViews::Slice["queries.all"].call(**)

  describe "with views on several screens" do
    before do
      create(:saved_view, screen: "tasks", name: "Next")
      create(:saved_view, screen: "posts", name: "Drafts")
      create(:saved_view, screen: "tasks", name: "Deploys")
      create(:saved_view, screen: "activity", name: "Week")
    end

    it "lists views by screen, then by name" do
      expect(all.map { [it.screen, it.name] }).to eq(
        [%w[activity Week], %w[posts Drafts], %w[tasks Deploys], %w[tasks Next]],
      )
    end

    it "lists one screen's views by name" do
      expect(all(screen: "tasks").map(&:name)).to eq(%w[Deploys Next])
    end
  end

  it "drops a filter its screen does not know" do
    create(:saved_view, screen: "tasks", filters: { q: "deploy", status: "open" })

    expect(all.map(&:filters)).to eq([{ "q" => "deploy" }])
  end

  it "lists nothing when no view exists" do
    expect(all).to eq([])
  end
end
