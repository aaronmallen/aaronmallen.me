Feature: Post responses
  A post lists its approved replies and mentions under Responses, oldest first, and counts its approved likes and
  reposts. A post with webmentions on advertises the endpoint.

  Background:
    Given the posts:
      | title | webmentions |
      | Hello | yes         |
      | Other |             |

  Scenario: An approved reply shows under Responses with an avatar, author, date and excerpt
    Given the post "Hello" has the webmentions:
      | type  | status   | author | excerpt  | received             |
      | reply | approved | Ada    | Good one | 2026-09-07T12:00:00Z |
    When I visit "/writing/hello"
    Then ".post-responses > h2.kicker" reads "Responses"
    And ".post-response-avatar[aria-hidden='true']" reads "A"
    And ".post-response .p-name" includes "Ada"
    And ".post-response time" includes "Sep 7, 2026"
    And ".post-response-text" includes "Good one"
    And the page has no axe breaches in light or dark

  Scenario: Responses list oldest first, the author linked to the source as a stranger's link
    Given the post "Hello" has the webmentions:
      | type    | author | received        | source                    |
      | reply   | Bea    | 1 minute ago    | https://ada.example/reply |
      | mention | Ada    | 2 minutes ago   | https://ada.example/other |
    When I visit "/writing/hello"
    Then the texts of ".post-response .p-name" are:
      | Ada |
      | Bea |
    And ".post-response:has-text('Bea') .post-response-author" has the attribute "href" set to "https://ada.example/reply"
    And ".post-response:has-text('Bea') .post-response-author" has the attribute "rel" set to "nofollow ugc noopener"

  Scenario: A response with no name falls back to the author's domain and shows no handle
    Given the post "Hello" has the webmentions:
      | type  | author | author url               |
      | reply | none   | https://ada.example/about |
    When I visit "/writing/hello"
    Then ".post-response .p-name" includes "ada.example"
    And the page has no ".post-response-handle"

  Scenario: A response shows the author's domain in lower case as the handle, and no blank excerpt
    Given the post "Hello" has the webmentions:
      | type  | author | author url                | excerpt |
      | reply | Ada    | https://Ada.example/about |         |
    When I visit "/writing/hello"
    Then ".post-response-head .post-response-handle" reads "ada.example"
    And the page has no ".post-response-text"

  Scenario Outline: <what> stay off the post
    Given the post "<post>" has the webmentions:
      | type     | status   | author       |
      | <type>   | <status> | <author>     |
    When I visit "/writing/hello"
    Then the page has no ".post-responses"
    And the page does not show "<author>"

    Examples:
      | what                   | post  | type    | status   | author          |
      | Pending replies        | Hello | reply   | pending  | Pending         |
      | Spam replies           | Hello | reply   | spam     | Spam            |
      | Ignored replies        | Hello | reply   | ignored  | Ignored reply   |
      | Ignored mentions       | Hello | mention | ignored  | Ignored mention |
      | Another post's replies | Other | reply   | approved | Elsewhere       |
      | Pending likes          | Hello | like    | pending  | Liker           |
      | Spam likes             | Hello | like    | spam     | Liker           |

  Scenario: Approved likes and reposts are counted with their icons, ignored ones not
    Given the post "Hello" has the webmentions:
      | type   | status   |
      | like   | approved |
      | like   | approved |
      | repost | approved |
      | like   | ignored  |
      | repost | ignored  |
    When I visit "/writing/hello"
    Then the texts of ".post-response-counts > span" are:
      | 2 likes  |
      | 1 repost |
    And the classes of ".post-response-counts i" are:
      | fa-solid fa-heart   |
      | fa-solid fa-retweet |

  Scenario: Counts show with no replies to list, leaving out a type nobody sent
    Given the post "Hello" has the webmentions:
      | type | status   |
      | like | approved |
      | repost | ignored |
    When I visit "/writing/hello"
    Then ".post-response-counts" includes "1 like"
    And ".post-response-counts" does not include "repost"
    And the page has ".post-responses"
    And the page has no ".post-response-list"

  Scenario: A post with webmentions on advertises the endpoint; one with them off and the index do not
    When I visit "/writing/hello"
    Then the page has "head link[rel='webmention'][href='/webmention']"
    When I visit "/writing/other"
    Then the page has no "head link[rel='webmention']"
    And the page has no ".post-responses"
    When I visit "/writing"
    Then the page has no "head link[rel='webmention']"
