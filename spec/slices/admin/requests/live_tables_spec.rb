# frozen_string_literal: true

RSpec.describe "Admin live tables", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:screens) do
    %w[
      /admin /admin/activity /admin/analytics /admin/calendar /admin/clients /admin/decisions /admin/decisions/new
      /admin/files /admin/health /admin/inbox /admin/journal /admin/links /admin/mail /admin/mail/settings
      /admin/people /admin/people/new /admin/performance /admin/performance/requests /admin/posts /admin/posts/new
      /admin/projects /admin/projects/new /admin/review /admin/search /admin/settings/security /admin/services
      /admin/social /admin/tags /admin/tasks /admin/tasks/new /admin/tasks/rules /admin/time /admin/tokens
      /admin/webmentions /admin/webmentions/settings
    ]
  end
  let(:records) do
    decision = create(:decision)
    project = create(:project)
    post = create(:post)
    task = create(:task)

    [
      "/admin/decisions/#{decision.id}", "/admin/decisions/#{decision.id}/edit", "/admin/projects/#{project.id}",
      "/admin/projects/#{project.id}/edit", "/admin/posts/#{post.id}/edit", "/admin/posts/#{post.id}/analytics",
      "/admin/tasks/#{task.id}", "/admin/tasks/#{task.id}/edit", "/admin/commits/#{create(:commit).id}",
      "/admin/pull-requests/#{create(:pull_request).id}", "/admin/tags/#{create(:tag).name}",
      "/admin/people/#{create(:person).id}/edit", "/admin/files/#{upload_share.value!.id}/edit",
      "/admin/files/groups/#{file_group.id}/edit", "/admin/links/#{short_link.id}/edit",
    ]
  end

  def file_group
    Shares::Slice["operations.upload_share_group"].call([share_upload("a", "a.txt", "text/plain")]).value!
  end

  def short_link = Shares::Slice["operations.create_short_link"].call({ destination: "https://example.com" }).value!

  def tables = page.find("main")["data-live-tables"]&.split

  before do
    sign_in_to_admin
    connect_share_store
    stub_request(:put, %r{\A#{share_store_url}/})
  end

  it "lists the tables on every live page", :aggregate_failures do
    (screens + records).each do |path|
      get path

      expect(last_response.status).to eq(200), path
      expect(tables).to include("tasks", "mail_threads"), path
    end
  end

  it "lists them on a page nothing lives at" do
    get "/admin/nowhere"

    expect(tables).to include("tasks")
  end

  it "lists the tables a page draws beside the ones the top bar reads" do
    get "/admin/calendar"

    expect(tables).to include("calendar_events", "task_tags", "tasks")
  end

  it "leaves out the tables a page does not draw" do
    get "/admin/calendar"

    expect(tables).not_to include("commits")
  end

  it "lists them on a form the CSRF check turns away" do
    post "/admin/tags", {}, { "HTTP_X_CSRF_TOKEN" => "wrong" }

    expect(tables).to include("tasks")
  end
end
