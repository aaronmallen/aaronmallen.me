# frozen_string_literal: true

RSpec.describe "Admin toast", type: :request do
  let(:app) do
    save = save_action
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
  let(:save_action) do
    Class.new(Admin::Action) do
      def handle(_request, response)
        toast(response, "Post saved")
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

      expect(page).to have_css("main + [role='status'][data-toast] .toast", text: "Post saved", visible: :all)
    end

    it "shows the toast only once" do
      follow_redirect!
      get "/admin"

      expect(page).to have_no_css("[data-toast]", visible: :all)
    end
  end

  it "shows no toast without a save" do
    get "/admin"

    expect(page).to have_no_css("[data-toast]", visible: :all)
  end
end
