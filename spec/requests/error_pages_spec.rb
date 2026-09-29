# frozen_string_literal: true

RSpec.describe "The error pages in production", type: :request do
  let(:app) { Hanami::Middleware::RenderErrors.new(site, production, errors_app) }
  let(:errors_app) { Hanami::Middleware::PublicErrorsApp.new(Hanami.app.root.join("public")) }
  let(:page) { Capybara.string(last_response.body) }
  let(:production) { Hanami::Config.new(app_name: Hanami.app.config.app_name, env: :production) }
  let(:site) { Hanami.app }

  shared_examples "a page of the site" do |status|
    it "answers #{status}" do
      expect(last_response.status).to eq(status)
    end

    it "answers HTML" do
      expect(last_response.content_type).to start_with("text/html")
    end

    it "carries the site name" do
      expect(page).to have_title(Blog::Owner.full_name).and have_css("header a[href='/']", text: Blog::Owner.full_name)
    end

    it "links home" do
      expect(page).to have_css("main a[href='/']")
    end

    it "loads nothing the app has to render", :aggregate_failures do
      expect(page).to have_no_css("[src], link[href], object, iframe", visible: :all)
      expect(page.all("style", visible: :all).map(&:text).join).not_to match(/url\(|@import/)
    end
  end

  describe "an unknown path" do
    let(:site) { ->(env) { raise Hanami::Router::NotFoundError, env } }

    before { get "/no-such-page" }

    it_behaves_like "a page of the site", 404
  end

  describe "a query the site cannot read" do
    before { get "/", {}, "QUERY_STRING" => "a=%" }

    it_behaves_like "a page of the site", 400
  end

  describe "an error raised in a public action" do
    before do
      replace_component("posts.queries.published_page", ->(_page) { raise "boom" })
      get "/writing"
    end

    it_behaves_like "a page of the site", 500
  end
end
