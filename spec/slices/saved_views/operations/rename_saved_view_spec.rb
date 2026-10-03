# frozen_string_literal: true

RSpec.describe SavedViews::Operations::RenameSavedView do
  include Dry::Monads[:result]

  def rename(id, params) = SavedViews::Slice["operations.rename_saved_view"].call(id, params)

  def stored(view) = SavedViews::Slice["relations.saved_views"].by_pk(view.id).one

  it "renames the view and leaves its filters alone" do
    view = create(:saved_view, name: "Old", filters: { q: "deploy" })
    rename(view.id, name: "  New  ")

    expect(stored(view)).to include(name: "New", filters: { "q" => "deploy" })
  end

  it "keeps a filter its screen dropped" do
    view = create(:saved_view, name: "Old", screen: "posts", filters: { status: "draft", tag: "ruby" })
    rename(view.id, name: "New")

    expect(stored(view)[:filters]).to eq("status" => "draft", "tag" => "ruby")
  end

  it "refuses a blank name" do
    view = create(:saved_view, name: "Old")

    expect(rename(view.id, name: " ")).to eq(Failure([:invalid, { name: ["blank"] }]))
  end

  it "keeps the old name when it refuses" do
    view = create(:saved_view, name: "Old")
    rename(view.id, name: "")

    expect(stored(view)[:name]).to eq("Old")
  end

  it "fails for an unknown view" do
    expect(rename(0, name: "New")).to eq(Failure(:not_found))
  end
end
