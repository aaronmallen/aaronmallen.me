# frozen_string_literal: true

require "open3"
require "tmpdir"

RSpec.describe "mise run lint:i18n", type: :script do
  def lint(sources, keys, allowed: [])
    Dir.mktmpdir do |root|
      write(root, ".config/i18n/allowed.yml", allowed.to_yaml)
      write(root, "slices/demo/config/i18n/en.yml", { "en" => keys }.to_yaml)
      sources.each { |path, source| write(root, path, source) }
      Open3.capture2e("scripts/lint/i18n", root, chdir: Hanami.app.root.to_s)
    end
  end

  def write(root, path, content)
    FileUtils.mkdir_p(File.dirname(File.join(root, path)))
    File.write(File.join(root, path), content)
  end

  let(:view) do
    <<~RUBY
      module Demo
        module UI
          module Views
            class Base < View
              def view_template = t(".heading")
            end
          end
        end
      end
    RUBY
  end

  let(:page) do
    <<~RUBY
      module Demo
        module UI
          module Views
            class Page < Base
              def lede = t("ui.views.page.ledes.\#{kind}")
            end
          end
        end
      end
    RUBY
  end

  let(:keys) do
    { "ui" => { "views" => { "page" => { "heading" => "Page", "ledes" => { "short" => "Hi" } } } } }
  end

  it "passes when code reads every key, a subclass's relative keys and prefixes among them", :aggregate_failures do
    output, status = lint({ "slices/demo/ui/views/base.rb" => view, "slices/demo/ui/views/page.rb" => page }, keys)

    expect(status).to be_success, output
  end

  it "fails on a key no code reads", :aggregate_failures do
    output, status = lint({ "slices/demo/ui/views/page.rb" => page }, keys)

    expect(status).not_to be_success
    expect(output).to include("ui.views.page.heading is in a locale file but no code reads it")
  end

  it "passes a key the allowed list names" do
    _, status = lint({ "slices/demo/ui/views/page.rb" => page }, keys, allowed: ["ui.views.*.heading"])

    expect(status).to be_success
  end
end
