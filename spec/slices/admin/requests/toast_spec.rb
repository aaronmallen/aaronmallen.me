# frozen_string_literal: true

RSpec.describe "Admin toast", type: :request do
  let(:app) do
    save = save_action(toast_key)
    middleware = Admin::Slice.config.actions.sessions.middleware

    Rack::Builder.new do
      map("/admin/save") do
        use(*middleware)
        run save
      end
      run Hanami.app
    end
  end

  let(:page) { Capybara.string(last_response.body) }
  let(:toast_key) { "tags_page.toasts.added" }

  def save_action(key)
    Class.new(Admin::Action) do
      define_method(:handle) do |_request, response|
        toast(response, key)
        response.redirect_to("/admin")
      end
    end.new
  end

  before { sign_in_to_admin }

  describe "after a save" do
    before { post "/admin/save", _csrf_token: admin_csrf_token }

    it "redirects" do
      expect(last_response).to be_redirect
    end

    it "shows the toast on the next page" do
      follow_redirect!

      expect(page).to have_css("main + [role='status'][data-toast] .toast", text: "Tag added", visible: :all)
    end

    it "shows the toast only once" do
      follow_redirect!
      get "/admin"

      expect(page).to have_no_css("[data-toast]", visible: :all)
    end
  end

  describe "with a key the locale lacks" do
    let(:toast_key) { "tags_page.toasts.dropped" }

    it "raises rather than show the key" do
      expect { post "/admin/save", _csrf_token: admin_csrf_token }.to raise_error(I18n::MissingTranslationData)
    end
  end

  it "shows no toast without a save" do
    get "/admin"

    expect(page).to have_no_css("[data-toast]", visible: :all)
  end
end
