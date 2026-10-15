# frozen_string_literal: true

module Public
  class Routes < Hanami::Routes
    TAG = %r{[^/]+}
    WRITING = Blog::Constants::WRITING_PATH

    get "/", to: "pages.index", as: :root
    get WRITING, to: "posts.index", as: :writing
    get "#{WRITING}.atom", to: "posts.feed", as: :writing_feed
    get "#{WRITING}/tags/:tag.atom", to: "tags.feed", as: :tag_feed, tag: TAG
    get "#{WRITING}/tags/:tag", to: "tags.show", as: :tag, tag: TAG
    get "#{WRITING}/:slug", to: "posts.show", as: :post
    get "/about", to: "pages.about", as: :about
    get "/projects", to: "pages.projects", as: :projects
    get "/projects/:slug", to: "projects.show", as: :project
    get "/projects/:slug/tasks/:number", to: "tasks.show", as: :project_task
    get "/contact", to: "pages.contact", as: :contact
    get "/privacy", to: "pages.privacy", as: :privacy
    get "/search", to: "search.index", as: :search
    get "/media/:key", to: "media.show", as: :media
    get "/media/:width/:key", to: "media.show", as: :media_width, width: /\d+/
    get "/site.webmanifest", to: "manifests.show", as: :manifest
    get "/sitemap.xml", to: "sitemaps.show", as: :sitemap
    get "/robots.txt", to: "robots.show", as: :robots
    post "/contact", to: "messages.create", as: :message
    post "/pulse", to: "visits.create", as: :visit
    post "/webmention", to: "webmentions.create", as: :webmention
  end
end
