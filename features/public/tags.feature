Feature: Tags
  A tag page lists the published posts and the live public projects that carry a public tag, with the tag's
  description. Tasks and journal entries share tag names but stay private.

  Scenario: A tag page lists published posts with the tag, newest first, rendered the way the index does
    Given the posts:
      | title | tags         | published     | summary          | status    |
      | Older | ruby         | 3 minutes ago | what it is about |           |
      | Newer | hanami, ruby | 2 minutes ago |                  |           |
      | Other | rust         | 1 minute ago  |                  |           |
      | Draft | ruby         |               |                  | draft     |
      | Later | ruby         | in 1 day      |                  | scheduled |
    When I visit "/writing/tags/ruby"
    Then the texts of ".entry .entry-title" are:
      | Newer |
      | Older |
    And ".entry-title a.entry-link[href='/writing/older']" reads "Older"
    And ".entry:has(a[href='/writing/older']) .entry-blurb" reads "what it is about"
    And the page has ".entry-meta a.post-tag[href='/writing/tags/ruby']"
    And the page has no axe breaches in light or dark

  Scenario: A tag page names the tag, has one h1 and links its own feed then the writing feed
    Given the posts:
      | title | tags |
      | Hello | ruby |
    And the projects:
      | name | tags |
      | sai  | ruby |
    When I visit "/writing/tags/ruby"
    Then ".hd h1" reads "Tagged ruby"
    And the page title is "Tagged ruby | Aaron Allen"
    And the page has 1 of "h1"
    And the hrefs and titles of "head link[rel='alternate'][type='application/atom+xml']" are:
      | /writing/tags/ruby.atom | Tagged ruby \| Aaron Allen |
      | /writing.atom           | Writing \| Aaron Allen     |
    And "link[rel='canonical']" has the attribute "href" set to "{site}/writing/tags/ruby"
    And "meta[property='og:url']" has the attribute "content" set to "{site}/writing/tags/ruby"

  Scenario: A tag with a dash in it is found
    Given the posts:
      | title | tags        |
      | Hello | open-source |
    When I visit "/writing/tags/open-source"
    Then ".entry-title" includes "Hello"

  Scenario Outline: A url that spells the tag with <difference> moves to the tag's own address
    Given the posts:
      | title | tags |
      | Hello | ruby |
    When I request "/writing/tags/<spelling>"
    Then it answers 301
    And the "Location" header is "/writing/tags/ruby"

    Examples:
      | spelling | difference    |
      | RUBY     | another case  |
      | %20ruby  | padding       |
      | rub%79   | an escape     |

  Scenario Outline: <what> gets the site's not found page
    Given the posts:
      | title | tags |
      | Hello | ruby |
    And <given>
    When I request "/writing/tags/<tag>"
    Then it answers 404
    And the "Content-Type" header starts with "text/html"
    And the body is the file "public/404.html"

    Examples:
      | what                                 | given                                                             | tag         |
      | A url that is no tag                 | I am not signed in                                                | open%20source |
      | A tag nothing carries                | I am not signed in                                                | rust        |
      | A tag only a task carries            | a task "clear the gutters" tagged "secret"                        | secret      |
      | A tag only a journal entry carries   | a journal entry "a private thought" tagged "secret"               | secret      |
      | A tag only a draft or scheduled post carries | a draft and a scheduled post tagged "secret"              | secret      |
      | A tag only an archived or private project carries | a private project tagged "secret" and an archived one tagged "secret" | secret |

  Scenario: A tag page never shows a task or journal entry that shares the tag, nor a private project
    Given the posts:
      | title | tags |
      | Hello | ruby |
    And a task "clear the gutters" tagged "ruby"
    And a journal entry "a private thought" tagged "ruby"
    And the projects:
      | name   | tags | visibility |
      | hidden | ruby | private    |
      | sai    | ruby |            |
    When I visit "/writing/tags/ruby"
    Then the page does not show "clear the gutters"
    And the page does not show "a private thought"
    And the texts of ".pgrid .pc .pn" are:
      | sai |

  Scenario: A tag's description renders from Markdown under the heading, as plain text in the meta tags
    Given the public tag "ruby" with the description:
      """
      notes on *ruby*

      and **hanami**
      """
    And the posts:
      | title | tags |
      | Hello | ruby |
    When I visit "/writing/tags/ruby"
    Then ".hd h1 + .ld em" reads "ruby"
    And the meta descriptions are all "notes on ruby and hanami"

  Scenario: An h1 in a tag's description becomes an h2
    Given the public tag "ruby" with the description:
      """
      # About ruby
      """
    And the posts:
      | title | tags |
      | Hello | ruby |
    When I visit "/writing/tags/ruby"
    Then the page has 1 of "h1"
    And ".ld h2" reads "About ruby"

  Scenario: A long description is cut to 160 characters in the meta tags
    Given the public tag "ruby" with the description:
      """
      word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word
      """
    And the posts:
      | title | tags |
      | Hello | ruby |
    When I visit "/writing/tags/ruby"
    Then the meta descriptions are all 160 characters, ending in an ellipsis

  Scenario: A tag without a description keeps the usual line, never the private tag's of the same name
    Given the private tag "ruby" with the description:
      """
      a private note
      """
    And a task "something" tagged "ruby"
    And the posts:
      | title | tags |
      | Hello | ruby |
    When I visit "/writing/tags/ruby"
    Then the meta descriptions are all "Posts and projects tagged ruby."
    And the page has no ".hd .ld"
    And the page does not show "a private note"

  Scenario: Paging a tag shows the newest 25, then the rest linking back, with the heading and canonical page
    Given 26 published posts tagged "ruby"
    And the posts:
      | title     | tags | published |
      | Elsewhere | rust | now       |
    And the projects:
      | name | tags |
      | sai  | ruby |
    When I visit "/writing/tags/ruby"
    Then the first of ".entry .entry-title" reads "Post 1" and the last "Post 25", 25 in all
    And "nav.pager a[rel='next'][href='/writing/tags/ruby?page=2']" reads "Older"
    And ".pgrid .pc .pn" reads "sai"
    When I visit "/writing/tags/ruby?page=2"
    Then the texts of ".entry .entry-title" are:
      | Post 26 |
    And "nav.pager a[rel='prev'][href='/writing/tags/ruby']" reads "Newer"
    And the page has no "nav.pager a[rel='next']"
    And ".hd h1" reads "Tagged ruby"
    And "link[rel='canonical']" has the attribute "href" set to "{site}/writing/tags/ruby?page=2"
    And the page has no ".pgrid"

  Scenario: A url spelling the tag another way keeps its page when it moves
    Given 26 published posts tagged "ruby"
    When I request "/writing/tags/RUBY?page=2"
    Then it answers 301
    And the "Location" header is "/writing/tags/ruby?page=2"

  Scenario Outline: The tag page <page> answers 404
    Given 26 published posts tagged "ruby"
    When I request "/writing/tags/ruby?page=<page>"
    Then it answers 404

    Examples:
      | page |
      | 3    |
      | 0    |
      | two  |

  Scenario: A later page of a tag only a project carries answers 404
    Given the projects:
      | name | tags |
      | sai  | go   |
    When I request "/writing/tags/go?page=2"
    Then it answers 404

  Scenario: A tag on writing and a project heads and lists each separately
    Given the posts:
      | title | tags |
      | Hello | ruby |
    And the projects:
      | name | tags | stars | release | tagline         |
      | sai  | ruby | 21    | v1.0    | Terminal colors |
    When I visit "/writing/tags/ruby"
    Then the texts of "h2.kicker" are:
      | Writing  |
      | Projects |
    And ".entries .entry-title" includes "Hello"
    And ".pgrid .pc .pn" reads "sai"
    And ".pc .ps" reads "ruby · ★ 21 · v1.0"

  Scenario: Only writing carrying the tag leaves the projects heading out
    Given the posts:
      | title | tags |
      | Hello | ruby |
    When I visit "/writing/tags/ruby"
    Then the texts of "h2.kicker" are:
      | Writing |
    And the page has no ".pgrid"

  Scenario: Only a project carrying the tag leaves the writing heading and its feed out
    Given the projects:
      | name | tags |
      | sai  | ruby |
    When I visit "/writing/tags/ruby"
    Then the texts of "h2.kicker" are:
      | Projects |
    And the page has no ".entries"
    And the hrefs and titles of "head link[rel='alternate'][type='application/atom+xml']" are:
      | /writing.atom | Writing \| Aaron Allen |
