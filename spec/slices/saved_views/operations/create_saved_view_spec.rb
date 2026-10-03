# frozen_string_literal: true

RSpec.describe SavedViews::Operations::CreateSavedView do
  include Dry::Monads[:result]

  def save(params) = SavedViews::Slice["operations.create_saved_view"].call(params)

  def stored(view) = SavedViews::Slice["relations.saved_views"].by_pk(view.id).one

  it "stores the name, the screen and the filters" do
    view = save(name: "  Open deploys  ", screen: "tasks", filters: { "filter" => "next", "q" => "deploy" }).value!

    expect(stored(view)).to include(name: "Open deploys", screen: "tasks",
                                    filters: { "filter" => "next", "q" => "deploy" })
  end

  it "stores the activity types as an object" do
    view = save(name: "Posts", screen: "activity", filters: { types: { post: "1" }, from: "2026-09-01" }).value!

    expect(stored(view)[:filters]).to eq("types" => { "post" => "1" }, "from" => "2026-09-01")
  end

  it "keeps only the filters its screen knows" do
    view = save(name: "Drafts", screen: "posts", filters: { status: "draft", page: "2", tag: "ruby" }).value!

    expect(stored(view)[:filters]).to eq("status" => "draft")
  end

  it "stores no filters when none come" do
    view = save(name: "Everything", screen: "journal").value!

    expect(stored(view)[:filters]).to eq({})
  end

  it "refuses a blank name" do
    expect(save(name: "   ", screen: "tasks", filters: {})).to eq(Failure([:invalid, { name: ["blank"] }]))
  end

  it "refuses a missing name" do
    expect(save(screen: "tasks", filters: {})).to eq(Failure([:invalid, { name: ["blank"] }]))
  end

  it "refuses a long name" do
    expect(save(name: "a" * 101, screen: "tasks", filters: {})).to eq(Failure([:invalid, { name: ["long"] }]))
  end

  it "refuses a name with control characters" do
    expect(save(name: "Open\u0007", screen: "tasks", filters: {})).to eq(Failure([:invalid, { name: ["control"] }]))
  end

  it "refuses an unknown screen" do
    expect(save(name: "Inbox", screen: "inbox", filters: { q: "x" })).to eq(Failure([:invalid, { screen: ["format"] }]))
  end

  it "refuses a missing screen" do
    expect(save(name: "Inbox", filters: {})).to eq(Failure([:invalid, { screen: ["blank"] }]))
  end

  it "refuses a filter that is not text" do
    expect(save(name: "Open", screen: "tasks", filters: { q: 3 })).to eq(Failure([:invalid, { filters: ["format"] }]))
  end

  it "refuses activity types that are not text" do
    expect(save(name: "Posts", screen: "activity", filters: { types: { post: 1 } }))
      .to eq(Failure([:invalid, { filters: ["format"] }]))
  end

  it "refuses an object for a filter other than the activity types" do
    expect(save(name: "Open", screen: "tasks", filters: { q: { a: "b" } }))
      .to eq(Failure([:invalid, { filters: ["format"] }]))
  end

  it "stores nothing it refuses" do
    save(name: "", screen: "tasks", filters: {})

    expect(SavedViews::Slice["relations.saved_views"].count).to eq(0)
  end
end
