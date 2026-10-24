Feature: Microformats
  Pages carry microformats for IndieWeb readers: one h-card on the home page, an h-feed of h-entries on the
  index, and on an article an h-entry with its author, dates, tags, syndication links and approved replies.

  Scenario: The home page carries one h-card, named and pointed at the root, with each profile rel=me
    When I visit "/"
    Then the page has 1 of ".h-card"
    And ".h-card a.p-name.u-url.u-uid" reads "Aaron Allen"
    And ".h-card a.p-name.u-url.u-uid" has the attribute "href" set to "/"
    And the links in ".h-card a.site-footer-link[rel=me]" go to:
      | https://github.com/aaronmallen           |
      | https://bsky.app/profile/aaronmallen.dev |
      | https://ruby.social/@aaronmallen         |

  Scenario: The index holds each entry in an h-feed, named, linked, dated and summarised
    Given the posts:
      | title | tags | summary          | body           | published            |
      | Hello | ruby | what it is about | the first part | 2026-09-07T12:00:00Z |
    When I visit "/writing"
    Then the page has 1 of ".h-feed > .h-entry"
    And ".h-entry a.p-name.u-url" reads "Hello"
    And ".h-entry a.p-name.u-url" has the attribute "href" set to "/writing/hello"
    And ".h-entry time.dt-published" has the attribute "datetime" set to "2026-09-07T07:00:00-05:00"
    And ".h-entry .p-summary" reads "what it is about"

  Scenario: An article is an h-entry with its name, url, date, body, categories and author
    Given the posts:
      | title | tags         | body     | published            |
      | Hello | ruby, hanami | the body | 2026-09-07T12:00:00Z |
    When I visit "/writing/hello"
    Then "article.h-entry h1.p-name" reads "Hello"
    And "article.h-entry data.u-url" has the attribute "value" set to "/writing/hello"
    And "article.h-entry time.dt-published" has the attribute "datetime" set to "2026-09-07T07:00:00-05:00"
    And "article.h-entry .e-content" includes "the body"
    And the texts of "article.h-entry a.p-category" are:
      | hanami |
      | ruby   |
    And "article.h-entry .p-author.h-card" has the attribute "href" set to "/"
    And "article.h-entry .p-author.h-card .p-name" reads "Aaron Allen"
    And the page has no ".dt-updated"
    And the page has no ".post-syndication"

  Scenario: The author link resolves to an h-card naming the same person on the page it links to
    When I visit "/"
    Then ".h-card a.p-name.u-url.u-uid" has the attribute "href" set to "/"
    And ".h-card a.p-name.u-url.u-uid" reads "Aaron Allen"

  Scenario: An article with edit notes carries one dt-updated, dated by the newest note
    Given the posts:
      | title | published            |
      | Hello | 2026-09-07T12:00:00Z |
    And the post "Hello" carries the edit notes:
      | note    | at                   |
      | one fix | 2026-09-07T13:00:00Z |
      | two fix | 2026-09-09T12:00:00Z |
    When I visit "/writing/hello"
    Then the page has 1 of "article.h-entry .dt-updated"
    And "article.h-entry time.dt-updated" has the attribute "datetime" set to "2026-09-09T07:00:00-05:00"

  Scenario: An article that went out on social links each network's post as a u-syndication
    Given the posts:
      | title |
      | Hello |
    And the post "Hello" went out on:
      | network  | url                                   |
      | bluesky  | https://bsky.example/ada/1            |
      | mastodon | https://social.example/@ada/1         |
      | linkedin | https://linkedin.example/feed/update/1 |
    When I visit "/writing/hello"
    Then the links in "article.h-entry a.u-syndication" go to:
      | https://bsky.example/ada/1             |
      | https://social.example/@ada/1          |
      | https://linkedin.example/feed/update/1 |
    And ".post-syndication" includes "Also posted on"
    And ".post-syndication" has a link "Bluesky" to "https://bsky.example/ada/1"
    And ".post-syndication" has a link "Mastodon" to "https://social.example/@ada/1"
    And the page has ".post-syndication a.u-syndication[href='https://linkedin.example/feed/update/1']:has-text('LinkedIn') i.fa-linkedin"

  Scenario: An approved reply is a u-comment h-cite with its source, author, date and excerpt
    Given the posts:
      | title |
      | Hello |
    And the post "Hello" has the webmentions:
      | type  | author | source                   | excerpt  | received             |
      | reply | Ada    | https://ada.example/reply | Good one | 2026-09-07T12:00:00Z |
    When I visit "/writing/hello"
    Then "article.h-entry .u-comment.h-cite a.u-url" has the attribute "href" set to "https://ada.example/reply"
    And "article.h-entry .u-comment.h-cite .p-author.h-card .p-name" reads "Ada"
    And "article.h-entry .u-comment.h-cite time.dt-published" has the attribute "datetime" set to "2026-09-07T07:00:00-05:00"
    And "article.h-entry .u-comment.h-cite .p-content" reads "Good one"
