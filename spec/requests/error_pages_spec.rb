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
      owner = Hanami.app.settings.owner_name

      expect(page).to have_title(owner).and have_css("header a[href='/']", text: owner)
    end

    it "keeps it from a shared cache" do
      expect(last_response.headers["Cache-Control"]).to be_nil
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

  describe "a body too large to read" do
    before { post "/contact", "message[body]=#{'a' * Blog::ParamsGuard::BODY_LIMIT}" }

    it_behaves_like "a page of the site", 413
  end

  describe "a multipart body where the site takes no files" do
    before { post "/contact", "photo" => Rack::Test::UploadedFile.new(StringIO.new("a"), original_filename: "a.jpg") }

    it_behaves_like "a page of the site", 415
  end

  describe "an error raised in a public action" do
    before do
      post_queries = instance_double(Posts::Repos::PostQueries)
      allow(post_queries).to receive(:published_page).and_raise("boom")
      replace_component("posts.repos.post_queries", post_queries)
      get "/writing"
    end

    it_behaves_like "a page of the site", 500
  end

  it "builds the pages in public/ from config/error_page.html", :aggregate_failures do
    Dir.mktmpdir do |dir|
      system("scripts/assets/error-pages", dir, exception: true)
      Dir.children(dir).each { |page| expect(File.read("#{dir}/#{page}")).to eq(File.read("public/#{page}")), page }
    end
  end
end
