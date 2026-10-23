Feature: Moderating webmentions in the admin
  The mentions screen lists webmentions by status, and the owner approves,
  ignores or marks each one as spam. Approving a reply or mention by hand
  trusts its author; marking one of theirs as spam stops trusting them.

  Background:
    Given I am signed in to the admin
    And a published post "Hello" taking webmentions

  Scenario: The mentions screen lists pending mentions and passes axe
    Given these webmentions on the post "Hello":
      | author_name | type  | status   |
      | Ada         | reply | pending  |
      | Grace       | like  | approved |
    When I visit "/admin/webmentions"
    Then the webmentions listed are "Ada"
    And the "pending" filter is checked
    And the webmentions screen tab "mentions" is current
    And the page has no axe breaches in light or dark

  Scenario Outline: The <status> filter shows only <status> mentions
    Given these webmentions on the post "Hello":
      | author_name | status   |
      | Ada         | pending  |
      | Grace       | approved |
      | Alan        | spam     |
      | Barbara     | ignored  |
    When I visit "/admin/webmentions?status=<status>"
    Then the webmentions listed are "<author>"
    And the "<status>" filter is checked
    And the webmention head says "1 pending · 1 shown on the site"

    Examples:
      | status   | author  |
      | pending  | Ada     |
      | approved | Grace   |
      | spam     | Alan    |
      | ignored  | Barbara |

  Scenario: The filters run pending, approved, ignored, then spam, and an unknown one shows pending
    Given these webmentions on the post "Hello":
      | author_name | status  |
      | Ada         | pending |
      | Alan        | spam    |
    When I visit "/admin/webmentions?status=junk"
    Then the filters run "pending, approved, ignored, spam"
    And the webmentions listed are "Ada"

  Scenario: The list pages through older mentions and keeps the filter
    Given 101 approved webmentions on the post "Hello"
    And these webmentions on the post "Hello":
      | author_name | status  |
      | Barbara     | pending |
    When I visit "/admin/webmentions?status=approved"
    Then 100 webmentions are listed
    And the webmention head says "1 pending · 101 shown on the site"
    And the pager links "Older" to "/admin/webmentions?status=approved&page=2"
    When I visit "/admin/webmentions?status=approved&page=2"
    Then the webmentions listed are "Author 101"
    And the pager links "Newer" to "/admin/webmentions?status=approved"
    And the "approved" filter is checked

  Scenario: No pager shows when one page holds every mention, and a page past the end is not found
    Given these webmentions on the post "Hello":
      | author_name | status   |
      | Ada         | approved |
    When I visit "/admin/webmentions?status=approved"
    Then the webmention page has no element "nav.pager"
    And GET "/admin/webmentions?status=approved&page=3" in the admin answers 404

  Scenario: Each mention shows its author, excerpt, kind, post and when it arrived
    Given these webmentions on the post "Hello":
      | author_name | type  | excerpt  | received_at            | source_url                 |
      | Ada         | reply | Good one | 2026-09-07T17:30:00Z   | http://203.0.113.7/notes/1 |
    When I visit "/admin/webmentions"
    Then the webmention from "Ada" shows "Good one"
    And the webmention from "Ada" shows "/writing/hello"
    And the webmention from "Ada" shows "Sep 7, 2026, 12:30"
    And the webmention from "Ada" arrived at "2026-09-07T12:30:00-05:00"
    And the author "Ada" links to "http://203.0.113.7/notes/1" in a new tab

  Scenario Outline: A <kind> wears a <color> label with an icon
    Given these webmentions on the post "Hello":
      | author_name | type   |
      | Ada         | <kind> |
    When I visit "/admin/webmentions"
    Then the webmention from "Ada" shows a "<kind>" label colored <color>

    Examples:
      | kind    | color |
      | reply   | sand  |
      | like    | pink  |
      | repost  | green |
      | mention | blue  |

  Scenario: A like says it carries no content
    Given these webmentions on the post "Hello":
      | author_name | type | excerpt |
      | Ada         | like | null    |
    When I visit "/admin/webmentions"
    Then the webmention from "Ada" shows "no content · like only"

  Scenario Outline: An empty <status> list says so
    Given these webmentions on the post "Hello":
      | author_name | status |
      | Alan        | <other> |
    When I visit "/admin/webmentions?status=<status>"
    Then I see "<empty>"

    Examples:
      | status   | other   | empty                 |
      | pending  | spam    | Nothing waiting.      |
      | ignored  | spam    | Nothing ignored.      |
      | approved | pending | Nothing approved yet. |

  Scenario: A seen pending mention is still listed, counted and open to every verdict
    Given these webmentions on the post "Hello":
      | author_name | seen_at |
      | Seen        | now     |
    When I visit "/admin/webmentions"
    Then the webmentions listed are "Seen"
    And the webmention head says "1 pending · 0 shown on the site"
    And the webmention from "Seen" offers "Approve, Ignore, Spam"

  Scenario Outline: A <status> mention offers <buttons>
    Given these webmentions on the post "Hello":
      | author_name | status   |
      | Ada         | <status> |
    When I visit "/admin/webmentions?status=<status>"
    Then the webmention from "Ada" offers "<buttons>"

    Examples:
      | status   | buttons               |
      | pending  | Approve, Ignore, Spam |
      | approved | Ignore, Spam          |
      | spam     | Approve, Ignore       |
      | ignored  | Approve, Spam         |

  Scenario: Approve and Spam wear icons and Ignore stays bare
    Given these webmentions on the post "Hello":
      | author_name |
      | Ada         |
    When I visit "/admin/webmentions"
    Then the webmention buttons wear:
      | Approve | fa-solid fa-check |
      | Ignore  | none              |
      | Spam    | fa-solid fa-ban   |

  Scenario Outline: <button> files the mention and says so
    Given these webmentions on the post "Hello":
      | author_name |
      | Ada         |
    When I visit "/admin/webmentions"
    And I press "<button>" on the webmention from "Ada"
    Then I see "<toast>"
    And the webmentions table has a row with:
      | author_name | status   | spam_reason |
      | Ada         | <status> | null        |

    Examples:
      | button  | status   | toast                              |
      | Approve | approved | Approved · now visible on the post |
      | Ignore  | ignored  | Ignored · hidden from the post     |
      | Spam    | spam     | Marked as spam                     |

  Scenario Outline: Spam keeps the note given with it, and a blank note is none
    Given these webmentions on the post "Hello":
      | author_name |
      | Ada         |
    When I visit "/admin/webmentions"
    Then I see the spam note field "Why spam? (optional)"
    When I mark the webmention from "Ada" as spam saying "<note>"
    Then the webmentions table has a row with:
      | author_name | status | spam_reason |
      | Ada         | spam   | <kept>      |

    Examples:
      | note      | kept      |
      | link farm | link farm |
      |           | null      |
      | \u3000\u00a0 | null   |

  Scenario Outline: <button> keeps no spam note and clears an old one
    Given these webmentions on the post "Hello":
      | author_name | status | spam_reason |
      | Ada         | spam   | link farm   |
    When I visit "/admin/webmentions?status=spam"
    Then the webmention from "Ada" shows "Spam: link farm"
    When I post to the admin "/admin/webmentions/1/<verdict>" with:
      | reason | link farm |
    Then the webmentions table has a row with:
      | author_name | status   | spam_reason |
      | Ada         | <status> | null        |

    Examples:
      | button  | verdict | status   |
      | Approve | approve | approved |
      | Ignore  | ignore  | ignored  |

  Scenario: Marking a spam mention as spam again without a note clears the note
    Given these webmentions on the post "Hello":
      | author_name | status | spam_reason |
      | Ada         | spam   | link farm   |
    When I visit "/admin/webmentions?status=spam"
    And I post to the admin "/admin/webmentions/1/spam"
    Then the webmentions table has a row with:
      | author_name | status | spam_reason |
      | Ada         | spam   | null        |

  Scenario: A verdict keeps the filter on the way back
    Given these webmentions on the post "Hello":
      | author_name | status |
      | Ada         | spam   |
    When I visit "/admin/webmentions?status=spam"
    And I press "Approve" on the webmention from "Ada"
    Then I am on "/admin/webmentions?status=spam"

  Scenario Outline: The <verdict> verdict is not found and changes nothing
    Given these webmentions on the post "Hello":
      | author_name |
      | Ada         |
    When I visit "/admin/webmentions"
    And I post to the admin "/admin/webmentions/1/<verdict>"
    Then the admin answers 404
    And the webmentions table has a row with:
      | author_name | status  |
      | Ada         | pending |

    Examples:
      | verdict  |
      | pending  |
      | approved |
      | ignored  |
      | delete   |

  Scenario Outline: Approving a <kind> by hand trusts its author and approves their waiting replies and mentions
    Given these webmentions on the post "Hello":
      | author_name | type   | author_url               | source_url                 |
      | Ada         | <kind> | http://203.0.113.7/about | http://203.0.113.7/notes/1 |
      | Reply       | reply  | http://203.0.113.7/about | http://203.0.113.7/notes/2 |
      | Like        | like   | http://203.0.113.7/about | http://203.0.113.7/notes/3 |
      | Repost      | repost | http://203.0.113.7/about | http://203.0.113.7/notes/4 |
      | Stranger    | reply  | http://203.0.113.8/about | http://203.0.113.8/notes/1 |
    When I visit "/admin/webmentions"
    And I press "Approve" on the webmention from "Ada"
    Then the trusted_authors table has a row with:
      | author_url               |
      | http://203.0.113.7/about |
    And the webmentions table has a row with:
      | author_name | status   |
      | Reply       | approved |
    And the webmentions table has a row with:
      | author_name | status  |
      | Like        | pending |
    And the webmentions table has a row with:
      | author_name | status  |
      | Repost      | pending |
    And the webmentions table has a row with:
      | author_name | status  |
      | Stranger    | pending |

    Examples:
      | kind    |
      | reply   |
      | mention |

  Scenario Outline: Approving a <kind> by hand leaves its author off the list
    Given these webmentions on the post "Hello":
      | author_name | type   | author_url               |
      | Ada         | <kind> | http://203.0.113.7/about |
    When I visit "/admin/webmentions"
    And I press "Approve" on the webmention from "Ada"
    Then the trusted_authors table holds 0 rows

    Examples:
      | kind   |
      | like   |
      | repost |

  Scenario: With auto-approve off, approving by hand trusts the author but leaves their other mentions waiting
    Given the webmention setting auto_approve_known_authors is off
    And these webmentions on the post "Hello":
      | author_name | author_url               |
      | Ada         | http://203.0.113.7/about |
      | Other       | http://203.0.113.7/about |
    When I visit "/admin/webmentions"
    And I press "Approve" on the webmention from "Ada"
    Then the trusted_authors table holds 1 rows
    And the webmentions table has a row with:
      | author_name | status  |
      | Other       | pending |

  Scenario: Approving an author already on the list approves nothing more
    Given the trusted author "http://203.0.113.7/about"
    And these webmentions on the post "Hello":
      | author_name | author_url               |
      | Ada         | http://203.0.113.7/about |
      | Waiting     | http://203.0.113.7/about |
    When I visit "/admin/webmentions"
    And I press "Approve" on the webmention from "Ada"
    Then the webmentions table has a row with:
      | author_name | status  |
      | Waiting     | pending |

  Scenario: Marking any of an author's mentions as spam stops trusting them, keeps their approved ones up, and a later approval trusts them again
    Given the trusted author "http://203.0.113.7/about"
    And these webmentions on the post "Hello":
      | author_name | author_url               | type    | status   |
      | Shown       | http://203.0.113.7/about | mention | approved |
      | Junk        | http://203.0.113.7/about | like    | pending  |
      | Later       | http://203.0.113.7/about | mention | pending  |
    When I visit "/admin/webmentions"
    And I press "Spam" on the webmention from "Junk"
    Then the trusted_authors table holds 0 rows
    And the webmentions table has a row with:
      | author_name | status   |
      | Shown       | approved |
    When I press "Approve" on the webmention from "Later"
    Then the trusted_authors table holds 1 rows

  Scenario: Ignoring keeps a trusted author trusted and trusts no one new
    Given the trusted author "http://203.0.113.7/about"
    And these webmentions on the post "Hello":
      | author_name | author_url               |
      | Ada         | http://203.0.113.7/about |
      | Grace       | http://203.0.113.8/about |
    When I visit "/admin/webmentions"
    And I press "Ignore" on the webmention from "Ada"
    And I press "Ignore" on the webmention from "Grace"
    Then the trusted_authors table holds 1 rows
    And the trusted_authors table has a row with:
      | author_url               |
      | http://203.0.113.7/about |

  Scenario: Approving a mention with no author URL trusts no one
    Given these webmentions on the post "Hello":
      | author_name | author_url |
      | Ada         | null       |
    When I visit "/admin/webmentions"
    And I press "Approve" on the webmention from "Ada"
    Then the trusted_authors table holds 0 rows

  Scenario: The mentions screen links to the webmention settings and leaves the cards to them
    When I visit "/admin/webmentions"
    Then I see the link "Settings" to "/admin/settings/webmentions#webmentions"
    And the webmention page has no element "#webmention-settings"
    And I do not see "Per post"

  Scenario: The old settings address goes to the webmentions tab, and the palette opens it
    Then GET "/admin/webmentions/settings" in the admin redirects to "/admin/settings/webmentions#webmentions"
    When I visit "/admin"
    Then the webmention page has the element "[data-palette-href='/admin/settings/webmentions']"

  Scenario: The palette leaves the pending count to Inbox
    Given these webmentions on the post "Hello":
      | author_name |
      | Ada         |
      | Grace       |
    When I visit "/admin"
    Then the webmention page has no element "#command-palette-webmentions .pal-r-sub"
