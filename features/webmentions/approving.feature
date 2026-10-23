Feature: Approving webmentions on arrival
  A reply or mention from a trusted author, on a page under that author's own
  path, skips review. Likes and reposts skip review while their switches are on.

  Background:
    Given a published post "Hello" taking webmentions

  Scenario Outline: A mention under the path of <what> is approved
    Given the trusted author "http://203.0.113.7/~ada"
    And the source page "<source>" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="<author>">Ada</a><a href="{post}">read</a></div>
      """
    When the webmention check runs for "<source>"
    Then the webmention from "<source>" has:
      | status   |
      | approved |

    Examples:
      | what                                          | source                             | author                   |
      | an author I approved before                   | http://203.0.113.7/~ada/notes/1    | http://203.0.113.7/~ada  |
      | that author under another case                | http://203.0.113.7/~ada/notes/1    | HTTP://203.0.113.7/~ada  |
      | that author with a trailing slash             | http://203.0.113.7/~ada/notes/1    | http://203.0.113.7/~ada/ |
      | the author holding an escape outside UTF-8    | http://203.0.113.7/~ada/%FF/1      | http://203.0.113.7/~ada  |
      | the author's own page                         | http://203.0.113.7/~ada            | http://203.0.113.7/~ada  |

  Scenario Outline: A mention from <what> waits for review
    Given the trusted author "http://203.0.113.7/~ada"
    And the source page "<source>" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="<author>">Ada</a><a href="{post}">read</a></div>
      """
    When the webmention check runs for "<source>"
    Then the webmention from "<source>" has:
      | status  |
      | pending |

    Examples:
      | what                                               | source                              | author                   |
      | a new host                                         | http://203.0.113.8/notes/1          | http://203.0.113.8/about |
      | another host claiming an author on a known host    | http://203.0.113.9/note             | http://203.0.113.7/~ada  |
      | a known host claiming an author elsewhere          | http://203.0.113.7/~ada/notes/1     | http://203.0.113.8/about |
      | another author on a known host                     | http://203.0.113.7/notes/2          | http://203.0.113.7/~grace |
      | a page outside a known author's path               | http://203.0.113.7/~grace/1         | http://203.0.113.7/~ada  |
      | a path that only starts with the same letters      | http://203.0.113.7/~adam/1          | http://203.0.113.7/~ada  |
      | a path that climbs out of the author's             | http://203.0.113.7/~ada/../~grace/1 | http://203.0.113.7/~ada  |
      | a path that climbs out under escapes               | http://203.0.113.7/~ada/%2e%2e/~grace/1 | http://203.0.113.7/~ada |
      | a path that climbs out behind an escaped slash     | http://203.0.113.7/~ada/..%2F~grace/1 | http://203.0.113.7/~ada |
      | a Bridgy page whose author's site is unknown       | http://brid.gy/comment/mastodon/1   | http://203.0.113.8/@ada  |

  Scenario: A mention on another scheme of the author's host waits for review
    Given the trusted author "https://203.0.113.7/~ada"
    And the source page "http://203.0.113.7/~ada/notes/1" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="https://203.0.113.7/~ada">Ada</a><a href="{post}">read</a></div>
      """
    When the webmention check runs for "http://203.0.113.7/~ada/notes/1"
    Then the webmention from "http://203.0.113.7/~ada/notes/1" has:
      | status  |
      | pending |

  Scenario Outline: A page that names no author waits for review <when>
    Given the trusted author "http://203.0.113.7/"
    And the webmention single-author hosts are "<hosts>"
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><markup><a href="{post}">read</a></div>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the webmention from "http://203.0.113.7/notes/1" has:
      | status  |
      | pending |

    Examples:
      | when                                      | hosts       | markup                                    |
      | even once its site is known               |             | <p>hi</p>                                 |
      | even on a host marked as one person's site | 203.0.113.7 | <p>hi</p>                                |
      | when the card carries no URL              |             | <span class="p-author h-card">Ada</span>  |

  Scenario Outline: An author at the root of a host is approved <when>
    Given the trusted author "<author>"
    And the webmention single-author hosts are "<hosts>"
    And the source page "<source>" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="<author>">Ada</a><a href="{post}">read</a></div>
      """
    When the webmention check runs for "<source>"
    Then the webmention from "<source>" has:
      | status   |
      | <status> |

    Examples:
      | when                                           | hosts         | author                  | source                          | status   |
      | only once the host is marked as one person's site |            | http://203.0.113.7/     | http://203.0.113.7/notes/1      | pending  |
      | from any page once the host is marked          | 203.0.113.7   | http://203.0.113.7/     | http://203.0.113.7/notes/1      | approved |
      | once a host named by its IPv6 address is marked | 2600:1f18::1 | http://[2600:1f18::1]/  | http://[2600:1f18::1]/notes/1   | approved |
      | not when another host is the one marked        | 203.0.113.8   | http://203.0.113.7/     | http://203.0.113.7/notes/1      | pending  |

  Scenario Outline: A known author waits for review <when>
    Given <setup>
    And the source page "http://203.0.113.8/about/1" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="http://203.0.113.8/about">Grace</a><a href="{post}">read</a></div>
      """
    When the webmention check runs for "http://203.0.113.8/about/1"
    Then the webmention from "http://203.0.113.8/about/1" has:
      | status  |
      | pending |

    Examples:
      | when                                                   | setup                                                                |
      | whose mentions were approved but who is not on the list | the webmention by "http://203.0.113.8/about" was approved before    |
      | whose only mention was ignored                         | the webmention by "http://203.0.113.8/about" was ignored before      |
      | once auto-approve is off                               | the trusted author "http://203.0.113.8/about" with auto-approve off  |
      | while the list is empty                                | the webmention setting auto_approve_known_authors is on              |
      | once its author is removed from the list               | the trusted author "http://203.0.113.8/about" was removed            |

  Scenario: A known author is still approved once one of their mentions was ignored
    Given the trusted author "http://203.0.113.8/about"
    And the webmention by "http://203.0.113.8/about" was ignored before
    And the source page "http://203.0.113.8/about/1" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="http://203.0.113.8/about">Grace</a><a href="{post}">read</a></div>
      """
    When the webmention check runs for "http://203.0.113.8/about/1"
    Then the webmention from "http://203.0.113.8/about/1" has:
      | status   |
      | approved |

  Scenario: The author of a like it approves stays off the list
    Given the source page "http://203.0.113.8/notes/1" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="http://203.0.113.8/about">Grace</a><a class="u-like-of" href="{post}">x</a></div>
      """
    When the webmention check runs for "http://203.0.113.8/notes/1"
    Then the webmention from "http://203.0.113.8/notes/1" has:
      | status   |
      | approved |
    And the trusted_authors table holds 0 rows

  Scenario Outline: A <kind> from an author it has never seen is approved
    Given the source page "http://203.0.113.8/notes/1" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="http://203.0.113.8/about">Grace</a><a class="u-<kind>-of" href="{post}">x</a></div>
      """
    When the webmention check runs for "http://203.0.113.8/notes/1"
    Then the webmention from "http://203.0.113.8/notes/1" has:
      | status   |
      | approved |

    Examples:
      | kind   |
      | like   |
      | repost |

  Scenario Outline: A <kind> from Bridgy is approved
    Given the source page "http://brid.gy/like/mastodon/1" reads:
      """
      <div class="h-entry"><div class="p-author h-card"><a class="u-url" href="http://203.0.113.8/@ada">Ada</a></div><a class="u-<kind>-of" href="{post}">x</a></div>
      """
    When the webmention check runs for "http://brid.gy/like/mastodon/1"
    Then the webmention from "http://brid.gy/like/mastodon/1" has:
      | status   |
      | approved |

    Examples:
      | kind   |
      | like   |
      | repost |

  Scenario Outline: A <kind> waits for review once <toggle> is off
    Given the webmention setting <toggle> is off
    And the source page "http://203.0.113.8/notes/1" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="http://203.0.113.8/about">Grace</a><a class="u-<kind>-of" href="{post}">x</a></div>
      """
    When the webmention check runs for "http://203.0.113.8/notes/1"
    Then the webmention from "http://203.0.113.8/notes/1" has:
      | status  |
      | pending |

    Examples:
      | kind   | toggle               |
      | like   | auto_approve_likes   |
      | repost | auto_approve_reposts |

  Scenario Outline: A <kind> from a known author on their own page is approved once <toggle> is off
    Given the webmention setting <toggle> is off
    And the trusted author "http://203.0.113.8/about"
    And the source page "http://203.0.113.8/about/1" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="http://203.0.113.8/about">Grace</a><a class="u-<kind>-of" href="{post}">x</a></div>
      """
    When the webmention check runs for "http://203.0.113.8/about/1"
    Then the webmention from "http://203.0.113.8/about/1" has:
      | status   |
      | approved |

    Examples:
      | kind   | toggle               |
      | like   | auto_approve_likes   |
      | repost | auto_approve_reposts |

  Scenario Outline: A changed <kind> stays approved while its switch is on
    Given the source page "http://203.0.113.8/notes/1" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="http://203.0.113.8/about">Grace</a><a class="u-<kind>-of" href="{post}">x</a></div>
      """
    And the webmention check runs for "http://203.0.113.8/notes/1"
    And the source page "http://203.0.113.8/notes/1" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="http://203.0.113.8/me">Grace</a><a class="u-<kind>-of" href="{post}">x</a></div>
      """
    When the webmention check runs for "http://203.0.113.8/notes/1"
    Then the webmention from "http://203.0.113.8/notes/1" has:
      | status   | author_url            |
      | approved | http://203.0.113.8/me |

    Examples:
      | kind   |
      | like   |
      | repost |

  Scenario Outline: A <kind> that was <status> stays <status> on a <change> resend
    Given the source page "http://203.0.113.8/notes/1" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="http://203.0.113.8/about">Grace</a><a class="u-<kind>-of" href="{post}">x</a></div>
      """
    And the webmention check runs for "http://203.0.113.8/notes/1"
    And the webmention from "http://203.0.113.8/notes/1" is <status>
    And the source page "http://203.0.113.8/notes/1" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="<author>">Grace</a><a class="u-<kind>-of" href="{post}">x</a></div>
      """
    When the webmention check runs for "http://203.0.113.8/notes/1"
    Then the webmention from "http://203.0.113.8/notes/1" has:
      | status   |
      | <status> |

    Examples:
      | kind   | status  | change    | author                   |
      | like   | pending | same      | http://203.0.113.8/about |
      | repost | pending | same      | http://203.0.113.8/about |
      | like   | spam    | changed   | http://203.0.113.8/me    |
      | repost | spam    | changed   | http://203.0.113.8/me    |

  Scenario Outline: The check fetches nothing once the post <what>
    Given the posts table holds:
      | title | status   | published_at   | webmentions_enabled |
      | Other | <status> | <published_at> | <enabled>           |
    When the webmention check runs for "http://203.0.113.7/notes/1" on the post "Other"
    Then the check gives up quietly
    And no webmention from "http://203.0.113.7/notes/1" is stored

    Examples:
      | what                    | status    | published_at | enabled |
      | went back to draft      | draft     | null         | true    |
      | turned webmentions off  | published | 1 hour ago   | false   |

  Scenario: The check fetches nothing for a post that is gone
    When the webmention check runs for "http://203.0.113.7/notes/1" on a post that is gone
    Then the check gives up quietly

  Scenario Outline: Once <what>, a mention kept before is removed when its source <change>
    Given these webmentions on the post "Hello":
      | source_url                 | excerpt |
      | http://203.0.113.7/notes/1 | First   |
    And <closed>
    And <source>
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then no webmention from "http://203.0.113.7/notes/1" is stored

    Examples:
      | what                            | closed                                 | change      | source                                                   |
      | the post turned webmentions off | the post "Hello" turns webmentions off | is gone     | the source page "http://203.0.113.7/notes/1" answers 410 |
      | receiving is off                | the webmention setting receive is off  | is gone     | the source page "http://203.0.113.7/notes/1" answers 410 |
      | the post turned webmentions off | the post "Hello" turns webmentions off | stops linking | the source page "http://203.0.113.7/notes/1" stops linking |
      | receiving is off                | the webmention setting receive is off  | stops linking | the source page "http://203.0.113.7/notes/1" stops linking |

  Scenario Outline: Once Bridgy is off, a Bridgy mention kept before is removed when its source answers <status>
    Given these webmentions on the post "Hello":
      | source_url                        |
      | http://brid.gy/comment/mastodon/1 |
    And the webmention setting accept_bridgy is off
    And the source page "http://brid.gy/comment/mastodon/1" answers <status>
    When the webmention check runs for "http://brid.gy/comment/mastodon/1"
    Then no webmention from "http://brid.gy/comment/mastodon/1" is stored

    Examples:
      | status |
      | 404    |
      | 410    |

  Scenario Outline: Once <what>, a mention kept before stays as it was while its source still links
    Given these webmentions on the post "Hello":
      | source_url | excerpt |
      | <source>   | First   |
    And <closed>
    And the source page "<source>" reads:
      """
      <div class="h-entry"><a href="{post}">read</a><p class="e-content">Second</p></div>
      """
    When the webmention check runs for "<source>"
    Then the webmention from "<source>" has:
      | excerpt |
      | First   |

    Examples:
      | what                            | closed                                      | source                            |
      | the post turned webmentions off | the post "Hello" turns webmentions off      | http://203.0.113.7/notes/1        |
      | receiving is off                | the webmention setting receive is off       | http://203.0.113.7/notes/1        |
      | Bridgy is off                   | the webmention setting accept_bridgy is off | http://brid.gy/comment/mastodon/1 |

  Scenario Outline: Once <what>, the check fetches nothing for a source it never kept
    Given <closed>
    When the webmention check runs for "<source>"
    Then the check gives up quietly
    And no webmention from "<source>" is stored

    Examples:
      | what                            | closed                                      | source                         |
      | the post turned webmentions off | the post "Hello" turns webmentions off      | http://203.0.113.8/notes/1     |
      | receiving is off                | the webmention setting receive is off       | http://203.0.113.8/notes/1     |
      | Bridgy is off                   | the webmention setting accept_bridgy is off | http://brid.gy/like/mastodon/1 |

  Scenario: The check still reads another source once Bridgy is off
    Given the webmention setting accept_bridgy is off
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><a href="{post}">read</a></div>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the webmentions table holds 1 rows

  Scenario: A mention that redirects outside the author's path waits for review
    Given the trusted author "http://203.0.113.7/~ada"
    And the source page "http://203.0.113.7/~ada/notes/1" redirects to "http://203.0.113.7/~grace/1"
    And the source page "http://203.0.113.7/~grace/1" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="http://203.0.113.7/~ada">Ada</a><a href="{post}">read</a></div>
      """
    When the webmention check runs for "http://203.0.113.7/~ada/notes/1"
    Then the webmention from "http://203.0.113.7/~ada/notes/1" has:
      | status  |
      | pending |
