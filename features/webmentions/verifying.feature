Feature: Checking a webmention's source
  The check reads the source page, keeps a mention only while the page links to
  the post, and reads its author, kind and excerpt from the page's markup.

  Background:
    Given a published post "Hello" taking webmentions

  Scenario: A source that links to the post is kept as a pending mention, received now
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><a href="{post}">read</a></div>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the webmention from "http://203.0.113.7/notes/1" has:
      | status  | post_id |
      | pending | 1       |
    And the webmentions table has a row with:
      | source_url                 | received_at |
      | http://203.0.113.7/notes/1 | set         |

  Scenario: The author, the kind and the excerpt come from the page
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="http://203.0.113.7/about">Ada</a>
      <a class="u-in-reply-to" href="{post}">re</a><p class="e-content">Nice</p></div>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the webmention from "http://203.0.113.7/notes/1" has:
      | author_name | author_url               | type  | excerpt |
      | Ada         | http://203.0.113.7/about | reply | Nice    |

  Scenario: The author URL is kept normalized, and the author domain comes from it
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="HTTP://203.0.113.7/about/#bio">Ada</a><a href="{post}">read</a></div>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the webmention from "http://203.0.113.7/notes/1" has:
      | author_url               | author_domain |
      | http://203.0.113.7/about | 203.0.113.7   |

  Scenario Outline: The check finds <what> to the post
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <markup>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the webmentions table holds 1 rows

    Examples:
      | what                       | markup                                                  |
      | a link with a fragment     | <a href="{post}#intro">read</a>                         |
      | a link with a trailing slash | <a href="{post}/">read</a>                            |
      | a link tag in the head     | <link rel="related" href="{post}">                      |
      | a link under another case  | <a href="{SITE}/writing/hello">read</a> |

  Scenario Outline: Nothing is kept when the page <what>
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <markup>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the check gives up quietly
    And no webmention from "http://203.0.113.7/notes/1" is stored

    Examples:
      | what                              | markup                                    |
      | links somewhere else              | <a href="{site}/writing/other">read</a>   |
      | only names the post in text       | <p>{post}</p>                             |
      | holds an href that is not a URL   | <a href="http://[bad">read</a>            |
      | holds a mail link                 | <a href="mailto:ada@example.com">write</a> |
      | holds a link with an empty href   | <a href="">read</a>                       |

  Scenario: Nothing is kept from an empty page
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <!-- nothing -->
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then no webmention from "http://203.0.113.7/notes/1" is stored

  Scenario: The mention kept before is removed once the link is gone
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><a href="{post}">read</a></div>
      """
    And the webmention check runs for "http://203.0.113.7/notes/1"
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <p>the link is gone</p>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then no webmention from "http://203.0.113.7/notes/1" is stored

  Scenario: The check reads no further than the first megabyte
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <p>{x*1000000}</p><a href="{post}">read</a>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then no webmention from "http://203.0.113.7/notes/1" is stored

  Scenario: The check reads a page the limit cuts through the middle of a character
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><a href="{post}">read</a></div>{☃*400000}
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the webmentions table holds 1 rows

  Scenario Outline: The check reads <what> as a <kind>
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><markup></div>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the webmention from "http://203.0.113.7/notes/1" has:
      | type   |
      | <kind> |

    Examples:
      | what                          | kind    | markup                                                                          |
      | a reply                       | reply   | <a class="u-in-reply-to" href="{post}">re</a>                                   |
      | a like                        | like    | <a class="u-like-of" href="{post}">x</a>                                        |
      | a repost                      | repost  | <a class="u-repost-of" href="{post}">x</a>                                      |
      | a property on a data element  | like    | <data class="u-like-of" value="{post}"></data><a href="{post}">read</a>         |
      | a property on another page    | mention | <a class="u-like-of" href="{site}/writing/other">x</a><a href="{post}">read</a> |
      | a plain link                  | mention | <a href="{post}">read</a>                                                       |

  Scenario Outline: The author comes from <what>
    Given the source page "<source>" reads:
      """
      <markup><a href="{post}">read</a>
      """
    When the webmention check runs for "<source>"
    Then the webmention from "<source>" has:
      | author_name | author_url |
      | <name>      | <url>      |

    Examples:
      | what                                  | source                         | name         | url                         | markup                                                                                                            |
      | a nested p-name and u-url             | http://203.0.113.7/notes/1     | Ada          | http://203.0.113.7/about    | <div class="h-entry"><div class="p-author h-card"><a class="u-url" href="http://203.0.113.7/about"><span class="p-name">Ada</span></a></div></div> |
      | the real author on a Bridgy page      | http://brid.gy/like/mastodon/1 | Ada          | http://203.0.113.8/@ada     | <div class="h-entry"><div class="p-author h-card"><a class="u-url" href="http://203.0.113.8/@ada">Ada</a></div></div> |
      | a rel=author link                     | http://203.0.113.7/notes/1     | Ada          | http://203.0.113.7/about    | <a rel="author" href="http://203.0.113.7/about">Ada</a>                                                           |
      | the source site with no author markup | http://203.0.113.7/notes/1     | null         | http://203.0.113.7/         | <p>hi</p>                                                                                                         |
      | the source site when the card has no URL | http://203.0.113.7/notes/1  | Ada          | http://203.0.113.7/         | <div class="h-entry"><span class="p-author h-card">Ada</span></div>                                               |
      | a card that holds only whitespace     | http://203.0.113.7/notes/1     | null         | http://203.0.113.7/about    | <div class="h-entry"><a class="p-author h-card" href="http://203.0.113.7/about">  </a></div>                      |
      | a name with whitespace squeezed out   | http://203.0.113.7/notes/1     | Ada Lovelace | http://203.0.113.7/         | <div class="h-entry"><div class="p-author h-card"><span class="p-name">  Ada   Lovelace </span></div></div>         |

  Scenario: A long author name is cut to the limit and marked
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="http://203.0.113.7/about">{Ada*300}</a><a href="{post}">read</a></div>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the stored author name is 500 characters ending in "…"

  Scenario: A family emoji stays whole where the author name is cut
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><div class="p-author h-card"><span class="p-name">{a*498}👩‍👩‍👧‍👦xy</span></div><a href="{post}">read</a></div>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the stored author_name is "a" repeated 498 times then "👩‍👩‍👧‍👦…"

  Scenario Outline: The excerpt <what>
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><markup><a href="{post}">read</a></div>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the webmention from "http://203.0.113.7/notes/1" has:
      | excerpt   |
      | <excerpt> |

    Examples:
      | what                                      | excerpt     | markup                                                              |
      | reads the e-content of the entry          | A fine post | <div class="e-content">A <b>fine</b> post</div>                     |
      | prefers the summary over the content      | Short       | <p class="p-summary">Short</p><div class="e-content">Long</div>     |
      | is none with no content markup            | null        | <span>plain</span>                                                  |
      | is none when the content is only whitespace | null      | <div class="e-content">   </div>                                    |
      | is none for a like                        | null        | <a class="u-like-of" href="{post}">x</a><div class="e-content">liked</div> |

  Scenario: The excerpt is read from content outside an h-entry
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="e-content">Loose</div><a href="{post}">read</a>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the webmention from "http://203.0.113.7/notes/1" has:
      | excerpt |
      | Loose   |

  Scenario: A long excerpt is cut to the limit and marked
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><div class="e-content">{word *300}</div><a href="{post}">read</a></div>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the stored excerpt is at most 500 characters ending in "…"

  Scenario: A family emoji stays whole where the excerpt is cut
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><div class="e-content">{a*498}👩‍👩‍👧‍👦xy</div><a href="{post}">read</a></div>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the stored excerpt is "a" repeated 498 times then "👩‍👩‍👧‍👦…"

  Scenario Outline: The mention kept before is removed once the source answers <status>
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><a href="{post}">read</a></div>
      """
    And the webmention check runs for "http://203.0.113.7/notes/1"
    And the source page "http://203.0.113.7/notes/1" answers <status>
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then no webmention from "http://203.0.113.7/notes/1" is stored

    Examples:
      | status |
      | 404    |
      | 410    |

  Scenario: A mention marked as spam stays, and its author stays unknown, once its source is gone
    Given these webmentions on the post "Hello":
      | source_url                 | author_url               | status |
      | http://203.0.113.7/notes/1 | http://203.0.113.7/about | spam   |
    And the source page "http://203.0.113.7/notes/1" answers 410
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the webmention from "http://203.0.113.7/notes/1" has:
      | status |
      | spam   |
    And the trusted_authors table holds 0 rows

  Scenario: A mention marked as spam stays once the link is gone
    Given these webmentions on the post "Hello":
      | source_url                 | status |
      | http://203.0.113.7/notes/1 | spam   |
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <p>nothing here</p>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the webmention from "http://203.0.113.7/notes/1" has:
      | status |
      | spam   |

  Scenario Outline: The check fails so Sidekiq tries again when the source <what>
    Given the source page "http://203.0.113.7/notes/1" answers <status>
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the check fails so Sidekiq tries again

    Examples:
      | what                  | status |
      | breaks                | 500    |
      | is down for now       | 503    |
      | asks us to slow down  | 429    |

  Scenario: The check fails so Sidekiq tries again when no resolver answers for the host
    When the webmention check runs for "http://no-such-host.invalid/notes/1"
    Then the check fails so Sidekiq tries again

  Scenario Outline: The check gives up at once and keeps nothing when the source answers <status>
    Given the source page "http://203.0.113.7/notes/1" answers <status>
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the check gives up quietly
    And no webmention from "http://203.0.113.7/notes/1" is stored

    Examples:
      | status |
      | 400    |
      | 403    |

  Scenario: The mention kept before stays while its source cannot be read
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><a href="{post}">read</a></div>
      """
    And the webmention check runs for "http://203.0.113.7/notes/1"
    And the source page "http://203.0.113.7/notes/1" answers 503
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the check fails so Sidekiq tries again
    And the webmentions table holds 1 rows

  Scenario Outline: The check sends nothing to <source>
    When the webmention check runs for "<source>"
    Then the check gives up quietly
    And no webmention from "<source>" is stored

    Examples:
      | source                                    |
      | http://127.0.0.1/admin                    |
      | http://10.0.0.5/admin                     |
      | http://192.168.1.1/admin                  |
      | http://172.16.0.1/admin                   |
      | http://169.254.169.254/latest/meta-data   |
      | http://[::1]/admin                        |
      | http://[fd00::1]/admin                    |
      | http://0.0.0.0/admin                      |
      | http://100.64.0.1/admin                   |
      | http://[64:ff9b::7f00:1]/admin            |
      | http://[2002:7f00:1::1]/admin             |
      | http://[::ffff:127.0.0.1]/admin           |
      | http://localhost/admin                    |
      | http://box.local/admin                    |
      | http://metadata.internal/admin            |
      | http://2130706433/admin                   |
      | http://0x7f000001/admin                   |
      | https:///notes/1                          |
      | ftp://203.0.113.7/note                    |
      | http://203.0.113.7:6379/                  |
      | http://exa mple.com                       |
      | http://10.1.2.3/notes/1                   |
      | http://[::7f00:1]/notes/1                 |
      | http://[2001:0:4136:e378:8000:63bf:3fff:fdd2]/notes/1 |
      | http://[64:ff9b:1::a01:203]/notes/1       |
      | http://[fec0::1]/notes/1                  |
      | http://[100::1]/notes/1                   |
      | http://[100:0:0:1::1]/notes/1             |
      | http://[2001:2::1]/notes/1                |
      | http://[2001:db8::1]/notes/1              |
      | http://[3fff::1]/notes/1                  |
      | http://[5f00::1]/notes/1                  |
      | http://[fe80::1]/notes/1                  |

  Scenario Outline: The check reads a source on port <port> named outright
    Given the source page "http://203.0.113.7:<port>/notes/1" reads:
      """
      <div class="h-entry"><a href="{post}">read</a></div>
      """
    When the webmention check runs for "http://203.0.113.7:<port>/notes/1"
    Then the webmentions table has a row with:
      | source_url                        |
      | http://203.0.113.7:<port>/notes/1 |

    Examples:
      | port |
      | 80   |
      | 443  |

  Scenario: The mention kept before stays once its host turns private
    Given these webmentions on the post "Hello":
      | source_url              |
      | http://10.1.2.3/notes/1 |
    When the webmention check runs for "http://10.1.2.3/notes/1"
    Then the webmentions table holds 1 rows

  Scenario: A second send from the same source updates the one mention
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><a href="{post}">read</a><p class="e-content">First</p></div>
      """
    And the webmention check runs for "http://203.0.113.7/notes/1"
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><a href="{post}">read</a><p class="e-content">Second</p></div>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the webmentions table holds 1 rows
    And the webmention from "http://203.0.113.7/notes/1" has:
      | excerpt |
      | Second  |

  Scenario Outline: A second send leaves a <status> mention <outcome> when <change>
    Given these webmentions on the post "Hello":
      | source_url                 | status   | author_name | author_url          | excerpt |
      | http://203.0.113.7/notes/1 | <status> | null        | http://203.0.113.7/ | First   |
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><a href="{post}">read</a><p class="e-content"><text></p><author></div>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the webmention from "http://203.0.113.7/notes/1" has:
      | status  | excerpt   |
      | <after> | <excerpt> |

    Examples:
      | status   | outcome          | change                    | text   | author                                                             | after    | excerpt |
      | spam     | spam             | the text changed          | Second |                                                                    | spam     | Second  |
      | ignored  | ignored          | the text changed          | Second |                                                                    | ignored  | Second  |
      | approved | approved         | it says the same thing    | First  |                                                                    | approved | First   |
      | approved | back at pending  | the text changed          | Second |                                                                    | pending  | Second  |
      | approved | back at pending  | the author changed        | First  | <a class="p-author h-card" href="http://203.0.113.7/about">Ada</a> | pending  | First   |

  Scenario: An approved mention with an overlong name stays approved when the name comes back the same
    Given the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="http://203.0.113.7/about">{Ada*300}</a><a href="{post}">read</a></div>
      """
    And the webmention check runs for "http://203.0.113.7/notes/1"
    And the webmention from "http://203.0.113.7/notes/1" is approved
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the webmention from "http://203.0.113.7/notes/1" has:
      | status   |
      | approved |

  Scenario: Relative markup resolves against where a redirect landed
    Given the source page "http://203.0.113.7/notes/1" moves for good to "http://203.0.113.10/notes/one"
    And the source page "http://203.0.113.10/notes/one" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="/about">Ada</a><a href="{post}">read</a></div>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the webmention from "http://203.0.113.7/notes/1" has:
      | author_url                |
      | http://203.0.113.10/about |

  Scenario: A relative redirect is followed and the mention is kept under the source it was sent
    Given the source page "http://203.0.113.7/notes/1" redirects to "/notes/one"
    And the source page "http://203.0.113.7/notes/one" reads:
      """
      <div class="h-entry"><a href="{post}">read</a></div>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the webmentions table holds 1 rows
    And the webmentions table has a row with:
      | source_url                 |
      | http://203.0.113.7/notes/1 |

  Scenario Outline: The check gives up at once and keeps nothing when the source redirects <what>
    Given the source page "http://203.0.113.7/notes/1" redirects to "<location>"
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the check gives up quietly
    And no webmention from "http://203.0.113.7/notes/1" is stored

    Examples:
      | what                             | location                   |
      | without naming where             |                            |
      | in a loop                        | http://203.0.113.7/notes/1 |
      | to somewhere that is not a URL   | http://[                   |

  Scenario Outline: The check follows no redirect to <what>
    Given the source page "http://203.0.113.7/notes/1" redirects to "<location>"
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the check gives up quietly
    And the web did not hear from the server at "<location>"

    Examples:
      | what                         | location                 |
      | a private address            | http://10.0.0.5/admin    |
      | a port that is not a web port | http://203.0.113.7:6379/ |

  Scenario: The check gives up and keeps nothing when the source claims a body over the limit
    Given the source page "http://203.0.113.7/notes/1" claims a body of 1000001 bytes
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the check gives up quietly
    And no webmention from "http://203.0.113.7/notes/1" is stored

  Scenario: The check fails so Sidekiq tries again when the source times out
    Given the source page "http://203.0.113.7/notes/1" reads after 11 seconds:
      """
      <div class="h-entry"><a href="{post}">read</a></div>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the check fails so Sidekiq tries again

  Scenario: Every redirect counts against the one time budget
    Given the source page "http://203.0.113.7/notes/1" redirects to "/notes/2" after 6 seconds
    And the source page "http://203.0.113.7/notes/2" redirects to "/notes/3" after 6 seconds
    And the source page "http://203.0.113.7/notes/3" reads after 6 seconds:
      """
      <div class="h-entry"><a href="{post}">read</a></div>
      """
    When the webmention check runs for "http://203.0.113.7/notes/1"
    Then the check fails so Sidekiq tries again
    And the webmentions table holds 0 rows
