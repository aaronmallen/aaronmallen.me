# frozen_string_literal: true

RSpec.describe "Public screens", type: :feature do
  def screens
    {
      "about" => "/about",
      "contact" => "/contact",
      "contact refused" => lambda do
        visit "/contact"
        click_button "Send message"
        assert_selector "#cf-email-error"
      end,
      "contact sent" => "/contact?sent=1",
      "home" => "/",
      "not found" => "/writing/nothing-here",
      "post" => "/writing/hello",
      "projects" => "/projects",
      "tag" => "/writing/tags/ruby",
      "writing" => "/writing",
    }
  end

  before do
    create(:tag, name: "ruby", color: "mk-violet")
    create(:project, name: "sai", tagline: "Terminal colors", tags: %w[ruby])
    create(
      :post,
      :published,
      body: <<~MARKDOWN,
        prose and `code`

        ```ruby
        # greets the reader
        class Greeter < Base
          def hello = puts("hello")
        end
        ```

        > a quote
      MARKDOWN
      slug: "hello",
      summary: "One line and no more",
      tags: %w[ruby],
      title: "A published post with a fairly long title",
    )
  end

  it_behaves_like "accessible screens"
  it_behaves_like "readable screens"
end
