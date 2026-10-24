Feature: SEO tags
  Every page carries Open Graph and Twitter tags, a canonical link built from the site setting, and a description
  of its own. A post's card can carry its own title, image and canonical link.

  Scenario: A page with nothing of its own is a website card with the site image and no description
    When I visit "/privacy"
    Then the meta tags "[property='og:type']" hold "website"
    And the meta tags "[property='og:site_name']" hold "Aaron Allen"
    And the meta tags "[property='og:title']" hold "Privacy"
    And "link[rel='canonical']" has the attribute "href" set to "{site}/privacy"
    And the meta tags "[property='og:url']" hold "{site}/privacy"
    And the meta tags "[name='twitter:card']" hold "summary_large_image"
    And the meta tags "[property='og:image']" hold "{site}{asset:share.png}"
    And the meta tags "[name='twitter:image']" hold the same as "[property='og:image']"
    And the meta tags "[property='og:image:alt']" hold "Aaron Allen's logo: black glasses in a white circle"
    And the meta tags "[name='twitter:image:alt']" hold the same as "[property='og:image:alt']"
    And the meta tags "[property='og:image:width']" hold "1200"
    And the meta tags "[property='og:image:height']" hold "630"
    And the meta tags "[name='theme-color']" hold "#faf4f2 | #222222"
    And the meta tags "[property='og:description']" hold ""
    And the meta tags "[name='description']" hold ""

  Scenario: The home page titles the card with the owner and roots the canonical link
    When I visit "/"
    Then the meta tags "[property='og:title']" hold "Aaron Allen"
    And the page title is "Writing and projects | Aaron Allen"
    And "link[rel='canonical']" has the attribute "href" set to "{site}/"

  Scenario: Each page has one description of its own, and a tag page names its tag
    Given the posts:
      | title | tags |
      | Hello | ruby |
    Then each of these pages has one description of its own in the meta, Open Graph and Twitter tags:
      | /                  |      |
      | /about             |      |
      | /projects          |      |
      | /contact           |      |
      | /writing           |      |
      | /writing/tags/ruby | ruby |

  Scenario: An article carrying nothing of its own is an article card described by its first paragraph
    Given the posts:
      | title | summary | body                                  | tags         | published            | updated              |
      | Hello |         | The opening paragraph\n\nthe second   | ruby, hanami | 2026-09-17T15:30:00Z | 2026-09-17T15:30:00Z |
    When I visit "/writing/hello"
    Then the meta tags "[property='og:type']" hold "article"
    And the meta tags "[property='og:title']" hold "Hello"
    And the meta tags "[property='og:description']" hold "The opening paragraph"
    And the meta tags "[name='twitter:description']" hold "The opening paragraph"
    And the meta tags "[name='description']" hold "The opening paragraph"
    And "link[rel='canonical']" has the attribute "href" set to "{site}/writing/hello"
    And the meta tags "[property='article:published_time']" hold "2026-09-17T15:30:00Z"
    And the meta tags "[property='article:modified_time']" hold "2026-09-17T15:30:00Z"
    And the meta tags "[property='article:author']" hold "Aaron Allen"
    And the meta tags "[property='article:tag']" hold "hanami | ruby"
    And the meta tags "[property='og:image']" match "/assets/share"
    And the meta tags "[name='twitter:card']" hold "summary_large_image"

  Scenario: A long first paragraph is cut to 160 characters in every description
    Given the posts:
      | title | body                                                                                                                                                                                                                                                                                                                                      |
      | Hello | word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word\n\nthe second |
    When I visit "/writing/hello"
    Then the meta descriptions are all 160 characters, ending in an ellipsis
    And the meta tags "[name='description']" match "^word word"

  Scenario: An article with no summary and no paragraph emits no empty description
    Given the posts:
      | title | summary | body              |
      | Hello |         | ## Only a heading |
    When I visit "/writing/hello"
    Then the meta tags "[name='description']" hold ""
    And the meta tags "[property='og:description']" hold ""
    And the meta tags "[name='twitter:description']" hold ""

  Scenario: An article keeps its whole long summary
    Given the posts:
      | title | summary                                                                                                                                                                                                                                                                                                         |
      | Hello | word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word |
    When I visit "/writing/hello"
    Then the meta tags "[name='description']" hold the summary of "Hello"

  Scenario: An article carrying its own card shows its title, summary, image and canonical link
    Given the posts:
      | title | summary          | og title    | image                        | canonical                       |
      | Hello | What it is about | On the card | https://example.com/card.png | https://elsewhere.example/hello |
    When I visit "/writing/hello"
    Then the meta tags "[property='og:title']" hold "On the card"
    And the page title is "Hello | Aaron Allen"
    And the meta tags "[property='og:description']" hold "What it is about"
    And the meta tags "[name='description']" hold "What it is about"
    And the meta tags "[property='og:image']" hold "https://example.com/card.png"
    And the meta tags "[name='twitter:image']" hold "https://example.com/card.png"
    And the meta tags "[property='og:image:alt']" hold "On the card"
    And the meta tags "[name='twitter:image:alt']" hold "On the card"
    And the meta tags "[property='og:image:width']" hold ""
    And the meta tags "[property='og:image:height']" hold ""
    And the meta tags "[name='twitter:card']" hold "summary_large_image"
    And "link[rel='canonical']" has the attribute "href" set to "https://elsewhere.example/hello"
    And the meta tags "[property='og:url']" hold "https://elsewhere.example/hello"

  Scenario: The projects page takes its image from the first public card that carries one
    Given the projects:
      | name   | image                          | visibility | stars |
      | hidden | https://example.com/hidden.png | private    | 9     |
      | plain  |                                |            | 8     |
      | sai    | https://example.com/sai.png    |            | 7     |
    When I visit "/projects"
    Then the meta tags "[property='og:image']" hold "https://example.com/sai.png"

  Scenario: The projects page falls back to the site image when no project carries one, or one is blank
    Given the projects:
      | name  | image |
      | plain |       |
    And the database runs:
      """
      INSERT INTO projects (name, visibility, og_image_url, started_on) VALUES ('blank', 'public', '', '2024-01-01')
      """
    When I visit "/projects"
    Then the meta tags "[property='og:image']" match "/assets/share"
