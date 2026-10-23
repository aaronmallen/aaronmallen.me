Feature: Sending webmentions
  Once a post is live, the sender reads each page the post links to, finds the
  page's webmention endpoint and tells it about the post. It remembers every
  link it found, and tries again later when a page or endpoint fails for now.

  Scenario: A post tells the endpoint each linked page advertises, as a form naming the post and the page
    Given the post "Hello" links to "http://203.0.113.7/notes/1, http://203.0.113.8/post"
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <link rel="webmention" href="http://203.0.113.7/webmention"><p>a note</p>
      """
    And the endpoint "http://203.0.113.7/webmention" answers 202
    And the source page "http://203.0.113.8/post" reads:
      """
      <link rel="webmention" href="http://203.0.113.8/webmention"><p>a post</p>
      """
    And the endpoint "http://203.0.113.8/webmention" answers 202
    When the webmention sender runs for the post "Hello"
    Then the sender finishes
    And the endpoint "http://203.0.113.7/webmention" was told about the post "Hello" for "http://203.0.113.7/notes/1"
    And the endpoint "http://203.0.113.8/webmention" was told about the post "Hello" for "http://203.0.113.8/post"
    And the page "http://203.0.113.7/notes/1" was read as the webmention agent asking for HTML
    And the post "Hello" remembers the targets "http://203.0.113.7/notes/1, http://203.0.113.8/post"

  Scenario: A page with no endpoint is still remembered
    Given the post "Hello" links to "http://203.0.113.7/notes/1"
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <p>a note</p>
      """
    When the webmention sender runs for the post "Hello"
    Then the sender finishes
    And the post "Hello" remembers the targets "http://203.0.113.7/notes/1"

  Scenario Outline: A page that <what> is skipped without a retry and still remembered
    Given the post "Hello" links to "<link>"
    And <page>
    When the webmention sender runs for the post "Hello"
    Then the sender finishes
    And the post "Hello" remembers the targets "<link>"

    Examples:
      | what                       | link                       | page                                                      |
      | is gone                    | http://203.0.113.7/notes/1 | the source page "http://203.0.113.7/notes/1" answers 404 |
      | sits on a private address  | http://10.1.2.3/notes/1    | the webmention setting send_on_publish is on              |

  Scenario Outline: The sender tries again later on a page that <what>
    Given the post "Hello" links to "<link>"
    And <page>
    When the webmention sender runs for the post "Hello"
    Then the sender fails so Sidekiq tries again

    Examples:
      | what                         | link                                | page                                                      |
      | answers 503                  | http://203.0.113.7/notes/1          | the source page "http://203.0.113.7/notes/1" answers 503 |
      | answers 429                  | http://203.0.113.7/notes/1          | the source page "http://203.0.113.7/notes/1" answers 429 |
      | no resolver answers for      | http://no-such-host.invalid/notes/1 | the webmention setting send_on_publish is on              |

  Scenario: The sender tells a page once it comes back
    Given the post "Hello" links to "http://203.0.113.7/notes/1"
    And the source page "http://203.0.113.7/notes/1" answers 503
    And the webmention sender runs for the post "Hello"
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <link rel="webmention" href="http://203.0.113.7/webmention">
      """
    When the webmention sender runs for the post "Hello"
    Then the stub was asked for "POST http://203.0.113.7/webmention"

  Scenario: A link named twice, or with a fragment, is told once
    Given the post "Hello" links to "http://203.0.113.7/notes/1, http://203.0.113.7/notes/1#part"
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <link rel="webmention" href="http://203.0.113.7/webmention">
      """
    When the webmention sender runs for the post "Hello"
    Then the stub was asked for "POST http://203.0.113.7/webmention"
    And the post "Hello" remembers the targets "http://203.0.113.7/notes/1"

  Scenario Outline: Nothing is sent for <what>
    Given the post "Hello" has the body "<body>"
    When the webmention sender runs for the post "Hello"
    Then the sender finishes
    And the post "Hello" remembers the targets ""

    Examples:
      | what                                         | body                                  |
      | a relative link, which resolves to the post  | [me](/about)                          |
      | a link back to this site                     | [other]({site}/writing/other)         |
      | a mail link                                  | [write](mailto:hello@aaronmallen.me)  |
      | a link to a fragment                         | [notes](#notes)                       |
      | a link that is not a URL                     | [broken](http://203.0.113.7:port/)    |
      | a post without links                         | no links here                         |

  Scenario Outline: The sender finds the endpoint in <what>
    Given the post "Hello" links to "http://203.0.113.7/notes/1"
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <markup>
      """
    When the webmention sender runs for the post "Hello"
    Then the stub was asked for "<endpoint>"

    Examples:
      | what                                   | markup                                                                                  | endpoint                              |
      | a link tag                             | <link rel="webmention" href="http://203.0.113.7/webmention">                            | POST http://203.0.113.7/webmention    |
      | an anchor                              | <a rel="webmention" href="http://203.0.113.7/webmention">wm</a>                         | POST http://203.0.113.7/webmention    |
      | the first of several the page names    | <link rel="webmention" href="/webmention"><a rel="webmention" href="/second">wm</a>     | POST http://203.0.113.7/webmention    |
      | an empty href, read as the page itself | <link rel="webmention" href="">                                                         | POST http://203.0.113.7/notes/1       |

  Scenario Outline: Nothing is sent for <what> on the linked page
    Given the post "Hello" links to "http://203.0.113.7/notes/1"
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <markup>
      """
    When the webmention sender runs for the post "Hello"
    Then the sender finishes

    Examples:
      | what                                | markup                                                            |
      | a page that advertises no endpoint  | <p>hello</p>                                                      |
      | an endpoint that is not a URL       | <link rel="webmention" href="http://exa mple.com/">               |
      | a page with an unrelated rel        | <link rel="pingback" href="http://203.0.113.7/pingback">          |

  Scenario: A post edited since its last send tells the links it has and a link it lost, then forgets the lost one
    Given the post "Hello" links to "http://203.0.113.7/notes/1"
    And the post "Hello" once linked to "http://203.0.113.8/post"
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <link rel="webmention" href="http://203.0.113.7/webmention">
      """
    And the source page "http://203.0.113.8/post" reads:
      """
      <link rel="webmention" href="http://203.0.113.8/webmention">
      """
    When the webmention sender runs for the post "Hello"
    Then the stub was asked for "POST http://203.0.113.7/webmention, POST http://203.0.113.8/webmention"
    And the post "Hello" remembers the targets "http://203.0.113.7/notes/1"

  Scenario: A page both linked and remembered is told once
    Given the post "Hello" links to "http://203.0.113.7/notes/1"
    And the post "Hello" once linked to "http://203.0.113.7/notes/1"
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <link rel="webmention" href="http://203.0.113.7/webmention">
      """
    When the webmention sender runs for the post "Hello"
    Then the stub was asked for "POST http://203.0.113.7/webmention"

  Scenario Outline: The sender finishes without a retry when the endpoint <what>
    Given the post "Hello" links to "http://203.0.113.7/notes/1"
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <link rel="webmention" href="<endpoint>">
      """
    And <reply>
    When the webmention sender runs for the post "Hello"
    Then the sender finishes

    Examples:
      | what                     | endpoint                         | reply                                                       |
      | answers 400              | http://203.0.113.7/webmention    | the endpoint "http://203.0.113.7/webmention" answers 400   |
      | answers 410              | http://203.0.113.7/webmention    | the endpoint "http://203.0.113.7/webmention" answers 410   |
      | sits on a private address | http://127.0.0.1/webmention     | the webmention setting send_on_publish is on                |

  Scenario: An endpoint that turns one send away leaves the other links told, and every link remembered
    Given the post "Hello" links to "http://203.0.113.7/notes/1, http://203.0.113.8/post"
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <link rel="webmention" href="http://203.0.113.7/webmention">
      """
    And the endpoint "http://203.0.113.7/webmention" answers 400
    And the source page "http://203.0.113.8/post" reads:
      """
      <link rel="webmention" href="http://203.0.113.8/webmention">
      """
    When the webmention sender runs for the post "Hello"
    Then the sender finishes
    And the stub was asked for "POST http://203.0.113.8/webmention"
    And the post "Hello" remembers the targets "http://203.0.113.7/notes/1, http://203.0.113.8/post"

  Scenario: A lost link whose endpoint turned the send away is forgotten
    Given the post "Hello" links to "http://203.0.113.7/notes/1"
    And the post "Hello" once linked to "http://203.0.113.8/post"
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <link rel="webmention" href="http://203.0.113.7/webmention">
      """
    And the endpoint "http://203.0.113.7/webmention" answers 202
    And the source page "http://203.0.113.8/post" reads:
      """
      <link rel="webmention" href="http://203.0.113.8/webmention">
      """
    And the endpoint "http://203.0.113.8/webmention" answers 400
    When the webmention sender runs for the post "Hello"
    Then the post "Hello" remembers the targets "http://203.0.113.7/notes/1"

  Scenario Outline: The sender tries again later when the endpoint answers <status>
    Given the post "Hello" links to "http://203.0.113.7/notes/1"
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <link rel="webmention" href="http://203.0.113.7/webmention">
      """
    And the endpoint "http://203.0.113.7/webmention" answers <status>
    When the webmention sender runs for the post "Hello"
    Then the sender fails so Sidekiq tries again

    Examples:
      | status |
      | 503    |
      | 429    |

  Scenario: An endpoint that fails for now leaves every link remembered
    Given the post "Hello" links to "http://203.0.113.7/notes/1, http://203.0.113.8/post"
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <link rel="webmention" href="http://203.0.113.7/webmention">
      """
    And the endpoint "http://203.0.113.7/webmention" answers 500
    And the source page "http://203.0.113.8/post" reads:
      """
      <link rel="webmention" href="http://203.0.113.8/webmention">
      """
    And the endpoint "http://203.0.113.8/webmention" answers 202
    When the webmention sender runs for the post "Hello"
    Then the sender fails so Sidekiq tries again
    And the post "Hello" remembers the targets "http://203.0.113.7/notes/1, http://203.0.113.8/post"

  Scenario: A lost link whose endpoint failed is kept, so the next try tells it
    Given the post "Hello" links to "http://203.0.113.7/notes/1"
    And the post "Hello" once linked to "http://203.0.113.8/post"
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <link rel="webmention" href="http://203.0.113.7/webmention">
      """
    And the endpoint "http://203.0.113.7/webmention" answers 202
    And the source page "http://203.0.113.8/post" reads:
      """
      <link rel="webmention" href="http://203.0.113.8/webmention">
      """
    And the endpoint "http://203.0.113.8/webmention" answers 500
    When the webmention sender runs for the post "Hello"
    Then the post "Hello" remembers the targets "http://203.0.113.7/notes/1, http://203.0.113.8/post"

  Scenario: A retry posts only to the endpoint that failed, then to every link once all took it
    Given the post "Hello" links to "http://203.0.113.7/notes/1, http://203.0.113.8/post"
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <link rel="webmention" href="http://203.0.113.7/webmention">
      """
    And the endpoint "http://203.0.113.7/webmention" answers 202
    And the source page "http://203.0.113.8/post" reads:
      """
      <link rel="webmention" href="http://203.0.113.8/webmention">
      """
    And the endpoint "http://203.0.113.8/webmention" answers 503
    When the webmention sender runs for the post "Hello"
    Then the sender fails so Sidekiq tries again
    When the webmention sender runs for the post "Hello"
    Then the sender fails so Sidekiq tries again
    And the endpoint "http://203.0.113.7/webmention" was told 1 time
    And the endpoint "http://203.0.113.8/webmention" was told 2 times
    And the post "Hello" remembers the targets "http://203.0.113.7/notes/1, http://203.0.113.8/post"
    Given the endpoint "http://203.0.113.8/webmention" answers 202
    When the webmention sender runs for the post "Hello"
    Then the sender finishes
    When the webmention sender runs for the post "Hello"
    Then the endpoint "http://203.0.113.7/webmention" was told 2 times
    And the endpoint "http://203.0.113.8/webmention" was told 4 times

  Scenario: Nothing is sent with the setting off
    Given the post "Hello" links to "http://203.0.113.7/notes/1"
    And the webmention setting send_on_publish is off
    When the webmention sender runs for the post "Hello"
    Then the sender finishes

  Scenario Outline: Nothing is sent for a <status> post
    Given the posts table holds:
      | title | status   | published_at | body                                |
      | Hello | <status> | <at>         | See [a note](http://203.0.113.7/n). |
    When the webmention sender runs for the post "Hello"
    Then the sender finishes

    Examples:
      | status    | at        |
      | draft     | null      |
      | scheduled | in 2 days |

  Scenario: The sender finishes quietly for a post that is gone
    When the webmention sender runs for a post that is gone
    Then the sender finishes

  Scenario Outline: The sender finds the endpoint in the Link header from <what>
    Given the post "Hello" links to "http://203.0.113.7/notes/1"
    And the source page "http://203.0.113.7/notes/1" sends the Link header '<header>' and reads:
      """
      <p>a note</p>
      """
    And the endpoint "http://203.0.113.7/webmention" answers 202
    When the webmention sender runs for the post "Hello"
    Then the endpoint "http://203.0.113.7/webmention" was told about the post "Hello" for "http://203.0.113.7/notes/1"

    Examples:
      | what                                     | header                                                                                     |
      | an unquoted rel                          | <http://203.0.113.7/webmention>; rel=webmention                                            |
      | a rel that lists webmention among others | <http://203.0.113.7/webmention>; rel="me webmention"                                       |
      | a relative endpoint                      | </webmention>; rel="webmention"                                                            |
      | a header with links for other rels first | <http://203.0.113.7/feed>; rel="alternate", <http://203.0.113.7/webmention>; rel="webmention" |

  Scenario: The Link header wins over the markup
    Given the post "Hello" links to "http://203.0.113.7/notes/1"
    And the source page "http://203.0.113.7/notes/1" sends the Link header "<http://203.0.113.7/webmention>; rel=\"webmention\"" and reads:
      """
      <link rel="webmention" href="http://203.0.113.7/markup">
      """
    And the endpoint "http://203.0.113.7/webmention" answers 202
    When the webmention sender runs for the post "Hello"
    Then the endpoint "http://203.0.113.7/webmention" was told 1 time
    And the web did not hear from the server at "http://203.0.113.7/markup"

  Scenario Outline: The sender ignores a Link header with <what>
    Given the post "Hello" links to "http://203.0.113.7/notes/1"
    And the source page "http://203.0.113.7/notes/1" sends the Link header '<header>' and reads:
      """
      <p>a note</p>
      """
    When the webmention sender runs for the post "Hello"
    Then the sender finishes
    And the endpoint "http://203.0.113.7/webmention" was told 0 times

    Examples:
      | what                             | header                                           |
      | a rel that only contains the word | <http://203.0.113.7/webmention>; rel="webmentions" |
      | no rel                           | <http://203.0.113.7/webmention>                  |

  Scenario: A relative endpoint resolves against where the page was read
    Given the post "Hello" links to "http://203.0.113.7/notes/1"
    And the source page "http://203.0.113.7/notes/1" moves for good to "http://203.0.113.7/notes/"
    And the source page "http://203.0.113.7/notes/" reads:
      """
      <link rel="webmention" href="wm">
      """
    And the endpoint "http://203.0.113.7/notes/wm" answers 202
    When the webmention sender runs for the post "Hello"
    Then the endpoint "http://203.0.113.7/notes/wm" was told 1 time

  Scenario: The sender tries again later on a page that times out
    Given the post "Hello" links to "http://203.0.113.7/notes/1"
    And the source page "http://203.0.113.7/notes/1" reads after 11 seconds:
      """
      <p>a note</p>
      """
    When the webmention sender runs for the post "Hello"
    Then the sender fails so Sidekiq tries again

  Scenario: The sender tries again later when the endpoint times out
    Given the post "Hello" links to "http://203.0.113.7/notes/1"
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <link rel="webmention" href="http://203.0.113.7/webmention">
      """
    And the endpoint "http://203.0.113.7/webmention" answers after 11 seconds
    When the webmention sender runs for the post "Hello"
    Then the sender fails so Sidekiq tries again
