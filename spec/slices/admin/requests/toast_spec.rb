# frozen_string_literal: true

RSpec.describe "Admin toast", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  def save_post
    post "/admin/posts", _csrf_token: admin_csrf_token, intent: "draft", post: { title: "Hello" }
  end

  before { sign_in_to_admin }

  describe "after a save" do
    before { save_post }

    it "redirects" do
      expect(last_response).to be_redirect
    end

    it "shows the toast on the next page" do
      follow_redirect!

      expect(page).to have_css("main + [role='status'][data-toast] .toast", text: "Draft saved", visible: :all)
    end

    it "shows the toast only once", :aggregate_failures do
      follow_redirect!
      expect(page).to have_css("[data-toast]", visible: :all)

      get last_request.path
      expect(Capybara.string(last_response.body)).to have_no_css("[data-toast]", visible: :all)
    end
  end

  it "shows no toast without a save" do
    get "/admin/posts/new"

    expect(page).to have_no_css("[data-toast]", visible: :all)
  end
end
