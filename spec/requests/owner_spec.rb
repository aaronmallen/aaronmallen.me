# frozen_string_literal: true

RSpec.describe "The owner", type: :request do
  before { allow(Hanami.app.settings).to receive(:owner).and_return({ name: "Ada Lovelace" }) }

  it "titles the page with the name the settings give" do
    get "/"

    expect(last_response.body).to include("<title>Ada Lovelace</title>")
  end

  it "names the site in the navigation" do
    get "/"

    expect(last_response.body).to include("Ada Lovelace, home")
  end

  it "splits the name across the brand mark" do
    get "/"

    expect(last_response.body).to include("<span>Ada</span>").and include("<span>Lovelace</span>")
  end

  it "leaves a one word name whole", :aggregate_failures do
    allow(Hanami.app.settings).to receive(:owner).and_return({ name: "Ada" })
    get "/"

    expect(last_response.body).to include("<span>Ada</span>")
    expect(last_response.body).not_to include("main-nav-brand-accent")
  end

  it "signs the feed with the name the settings give" do
    create(:post, :published, slug: "hello")
    get "/writing.atom"

    expect(last_response.body).to include("<name>Ada Lovelace</name>")
  end
end
