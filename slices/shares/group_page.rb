# auto_register: false
# frozen_string_literal: true

module Shares
  class GroupPage < Phlex::HTML
    IMAGE = %r{\Aimage/}
    DOWNLOAD = "Download all"
    TITLE = "Shared files"
    STYLE = <<~CSS
      :root {
        color-scheme: light dark;
        --ground: light-dark(#faf4f2, #222222);
        --ink: light-dark(#29242a, #f7f1ff);
        --line: light-dark(#d3cdcc, #363537);
        --accent: light-dark(#b31d4b, #fc618d);
      }

      body {
        margin: 0;
        background: var(--ground);
        color: var(--ink);
        font-family: "Helvetica Neue", Helvetica, Arial, sans-serif;
        line-height: 1.6;
      }

      header {
        padding: 1.25rem 1.5rem;
        border-bottom: 1px solid var(--line);
      }

      header a {
        color: var(--ink);
        font-weight: 700;
        text-decoration: none;
      }

      main {
        max-width: 60rem;
        margin: 0 auto;
        padding: 2rem 1.5rem 4rem;
      }

      h1 {
        margin: 0 0 1.5rem;
        font-size: 2.25rem;
        line-height: 1.2;
      }

      ul {
        margin: 0;
        padding: 0;
        list-style: none;
      }

      .carousel {
        display: flex;
        gap: 1rem;
        margin-bottom: 2rem;
        overflow-x: auto;
        scroll-snap-type: x mandatory;
      }

      .carousel li {
        flex: 0 0 100%;
        scroll-snap-align: center;
      }

      .carousel img {
        display: block;
        width: 100%;
        max-height: 75vh;
        object-fit: contain;
      }

      .download {
        display: inline-block;
        margin-bottom: 2rem;
        padding: 0.5rem 1.25rem;
        border-radius: 0.375rem;
        background: var(--accent);
        color: var(--ground);
        font-weight: 700;
        text-decoration: none;
      }

      .files li {
        padding: 0.75rem 0;
        border-top: 1px solid var(--line);
      }

      .files a {
        color: var(--accent);
        overflow-wrap: anywhere;
      }
    CSS

    def initialize(group, settings)
      super()
      @group = group
      @settings = settings
    end

    def view_template
      doctype
      html(lang: "en") do
        head { render_head }
        body { render_body }
      end
    end

    private

    def file_path(file) = "/#{@group.code}/#{file.id}"

    def heading = @group.name || TITLE

    def images = split.first

    def others = split.last

    def render_body
      header { a(href: @settings.site_url) { @settings.owner_name } }
      main do
        h1 { heading }
        a(class: "download", href: "/#{@group.code}.zip", download: "") { DOWNLOAD }
        render_images
        render_files
      end
    end

    def render_files
      return if others.empty?

      ul(class: "files") do
        others.each { |file| li { a(href: file_path(file)) { file.filename } } }
      end
    end

    def render_head
      meta(charset: "utf-8")
      meta(name: "viewport", content: "width=device-width, initial-scale=1")
      meta(name: "robots", content: "noindex")
      title { "#{heading} | #{@settings.owner_name}" }
      style { raw(safe(STYLE)) }
    end

    def render_images
      return if images.empty?

      ul(class: "carousel") do
        images.each do |file|
          li do
            a(href: file_path(file)) do
              img(src: "#{file_path(file)}?preview", alt: file.alt_text || file.filename, loading: "lazy")
            end
          end
        end
      end
    end

    def split = @split ||= @group.share_group_files.partition { IMAGE.match?(it.content_type) }
  end
end
