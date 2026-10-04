# frozen_string_literal: true

RSpec.describe SavedViews::Operations::ChangeSavedView do
  include Dry::Monads[:result]

  def change(id, params) = SavedViews::Slice["operations.change_saved_view"].call(id, params)

  def stored(view) = SavedViews::Slice["relations.saved_views"].by_pk(view.id).one

  it "replaces the filters and leaves the name alone" do
    view = create(:saved_view, name: "Open", filters: { filter: "next", q: "deploy" })
    change(view.id, filters: { pool: "github" })

    expect(stored(view)).to include(name: "Open", filters: { "pool" => "github" })
  end

  it "renames the view and replaces its filters in one write" do
    view = create(:saved_view, name: "Open", filters: { q: "deploy" })
    change(view.id, name: " Shipping ", filters: { q: "ship" })

    expect(stored(view)).to include(name: "Shipping", filters: { "q" => "ship" })
  end

  it "keeps the old name when it refuses the filters" do
    view = create(:saved_view, name: "Open", filters: { q: "deploy" })
    change(view.id, name: "Shipping", filters: { q: "sh\0ip" })

    expect(stored(view)).to include(name: "Open", filters: { "q" => "deploy" })
  end

  it "drops a filter its screen does not know" do
    view = create(:saved_view, screen: "posts", filters: { status: "draft", tag: "ruby" })
    change(view.id, filters: { status: "published", page: "4" })

    expect(stored(view)[:filters]).to eq("status" => "published")
  end

  it "clears the filters when none come" do
    view = create(:saved_view, filters: { q: "deploy" })
    change(view.id, {})

    expect(stored(view)[:filters]).to eq({})
  end

  it "refuses a filter that is not text" do
    view = create(:saved_view, filters: { q: "deploy" })

    expect(change(view.id, filters: { q: ["deploy"] })).to eq(Failure([:invalid, { filters: ["format"] }]))
  end

  it "keeps the old filters when it refuses" do
    view = create(:saved_view, filters: { q: "deploy" })
    change(view.id, filters: { q: 1 })

    expect(stored(view)[:filters]).to eq("q" => "deploy")
  end

  it "fails for an unknown view" do
    expect(change(0, filters: {})).to eq(Failure(:not_found))
  end
end
