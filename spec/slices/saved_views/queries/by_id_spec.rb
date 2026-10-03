# frozen_string_literal: true

RSpec.describe SavedViews::Queries::ById do
  def load(view) = SavedViews::Slice["queries.by_id"].call(view.id)

  it "keeps the filters its screen knows" do
    view = create(:saved_view, screen: "tasks", filters: { filter: "next", pool: "github", q: "deploy" })

    expect(load(view).filters).to eq("filter" => "next", "pool" => "github", "q" => "deploy")
  end

  it "drops a filter its screen does not know" do
    view = create(:saved_view, screen: "posts", filters: { status: "draft", tag: "ruby", page: "3" })

    expect(load(view).filters).to eq("status" => "draft")
  end

  it "keeps the activity types as an object" do
    view = create(:saved_view, screen: "activity", filters: { types: { post: "1", task: "1" }, q: "kayak", sort: "x" })

    expect(load(view).filters).to eq("types" => { "post" => "1", "task" => "1" }, "q" => "kayak")
  end

  it "loads a view whose every filter its screen dropped" do
    view = create(:saved_view, screen: "journal", filters: { mood: "calm" })

    expect(load(view).filters).to eq({})
  end

  it "leaves the stored row as it was" do
    view = create(:saved_view, screen: "posts", filters: { status: "draft", tag: "ruby" })
    load(view)

    expect(SavedViews::Slice["relations.saved_views"].by_pk(view.id).one[:filters]).to eq(
      "status" => "draft", "tag" => "ruby",
    )
  end

  it "finds nothing for an unknown id" do
    expect(SavedViews::Slice["queries.by_id"].call(0)).to be_nil
  end
end
