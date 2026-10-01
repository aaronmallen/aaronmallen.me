# frozen_string_literal: true

RSpec.describe "Admin Markdown editor", type: :feature do
  let(:two_editors) do
    Class.new(Admin::UI::View) do
      def initialize(**) = super()

      def view_template
        h1 { "Two editors" }
        %w[posts tasks].each do |renderer|
          Form(action: "/admin/posts") do
            MarkdownEditor(
              name: "#{renderer}[body]", value: "", height: "160px", renderer:, id: "#{renderer}-body",
              label: "#{renderer.capitalize} body",
            )
          end
        end
      end
    end
  end

  def editor(renderer) = find("[data-markdown-editor]:has(##{renderer}-body)")

  def show_view(renderer, name) = editor(renderer).find(".seg-option", text: name).click

  before do
    stub_const("Admin::UI::Views::TwoEditors", two_editors)
    replace_component("ui.views.posts.new", two_editors)
    sign_in_to_admin
    visit "/admin/posts/new"
  end

  it "switches one editor to Preview and leaves the other on Write", :aggregate_failures do
    show_view "posts", "Preview"

    expect(editor("posts")).to have_no_field("Posts body")
    expect(editor("tasks")).to have_field("Tasks body")
  end

  it "sets each editor's height" do
    expect(evaluate_script("document.getElementById('tasks-body').getBoundingClientRect().height")).to be >= 160
  end

  it "inserts a snippet in its own editor only", :aggregate_failures do
    editor("tasks").find("[role='toolbar'] button[aria-label='Bold']").click

    expect(find_field("Tasks body").value).to eq("**bold**")
    expect(find_field("Posts body").value).to eq("")
  end

  describe "previewing both editors" do
    let(:html) { "<details><summary>More</summary>hidden</details>" }

    before do
      fill_in "Posts body", with: html
      fill_in "Tasks body", with: html
      show_view "posts", "Preview"
      show_view "tasks", "Preview"
      editor("posts").assert_selector(".preview .post-body")
    end

    it "keeps the HTML the task renderer allows" do
      expect(editor("tasks")).to have_css(".preview details summary", text: "More")
    end

    it "drops the HTML through the post renderer" do
      expect(editor("posts")).to have_no_css(".preview details")
    end
  end

  it "strips a raw script from the task preview", :aggregate_failures do
    fill_in "Tasks body", with: "<script>window.ran = true</script>\n\nsafe"
    show_view "tasks", "Preview"

    expect(editor("tasks")).to have_css(".preview p", exact_text: "safe")
    expect(editor("tasks")).to have_no_css(".preview script", visible: :all)
    expect(evaluate_script("window.ran")).to be_nil
  end

  describe "after a first preview" do
    before do
      fill_in "Tasks body", with: "first"
      show_view "tasks", "Preview"
      editor("tasks").assert_selector(".preview p", exact_text: "first")
      show_view "tasks", "Write"
    end

    it "previews the body as it stands on the next switch" do
      fill_in "Tasks body", with: "second"
      show_view "tasks", "Preview"

      expect(editor("tasks")).to have_css(".preview p", exact_text: "second")
    end
  end
end
