Feature: Visits
  The beacon at /pulse records a view of a page on the site, then its read time, scroll depth and the links
  clicked from it. It stores no address and no user agent, only hashes, the referrer's host, the source a ref
  names and the class of device. It turns away anything that names no page or no view, and limits each sender.

  Background:
    Given my requests send the header "User-Agent" as "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36"
    And the posts:
      | title | tags |
      | Hello | ruby |

  Scenario: A view is accepted with nothing to read and no cookie, stored once with its page and no address
    When I send a beacon:
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello", "view_token": "{token:first}"}
      """
    Then it answers 202
    And the answer is empty
    And there is no "Set-Cookie" header
    And the database answers "/writing/hello, Hello, 0" for:
      """
      SELECT path, title, read_seconds FROM analytics_events
      """
    And the database answers "0" for:
      """
      SELECT count(*) FROM analytics_events WHERE row_to_json(analytics_events)::text LIKE '%127.0.0.1%'
      """

  Scenario: A view a browser sends, asking for anything, is accepted
    Given my requests send the header "Accept" as "*/*"
    When I send a beacon:
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello", "view_token": "{token:first}"}
      """
    Then it answers 202

  Scenario: One address and browser get one visitor hash, and a monthly hash beside the daily one
    When I send 2 beacons:
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello", "view_token": "{token:view-{n}}"}
      """
    Then the database answers "1" for:
      """
      SELECT count(DISTINCT visitor_hash) FROM analytics_events
      """
    And the database answers "true" for:
      """
      SELECT bool_and(month_visitor_hash ~ '^[0-9a-f]{64}$' AND month_visitor_hash <> visitor_hash) FROM analytics_events
      """

  @timeout:180_000
  Scenario: In production a client forging X-Forwarded-For, which is not the proxy's header, gets one visitor hash
    Given the site runs in production
    When I send a beacon with the header "X-Forwarded-For" as "203.0.113.1":
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello"}
      """
    And I send a beacon with the header "X-Forwarded-For" as "203.0.113.2":
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello"}
      """
    Then the database answers "1" for:
      """
      SELECT count(DISTINCT visitor_hash) FROM analytics_events
      """

  Scenario: Another browser gets another visitor hash
    When I send a beacon:
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello"}
      """
    And I send a beacon as "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/130.0":
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello"}
      """
    Then the database answers "2" for:
      """
      SELECT count(DISTINCT visitor_hash) FROM analytics_events
      """

  @timeout:180_000
  Scenario: In production two addresses in one IPv6 /64 get two visitor hashes
    Given the site runs in production
    When I send 2 beacons from the addresses "2001:db8:1:2::N":
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello"}
      """
    Then the database answers "2" for:
      """
      SELECT count(DISTINCT visitor_hash) FROM analytics_events
      """

  Scenario Outline: A view with the referrer <referrer> keeps <host> and <path>
    When I send a beacon:
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello", "referrer": "<referrer>"}
      """
    Then it answers 202
    And the database answers "<host>|<path>" for:
      """
      SELECT coalesce(referrer_host, 'no host') || '|' || coalesce(referrer_path, 'no path') FROM analytics_events
      """

    Examples:
      | referrer                                | host         | path           |
      | https://news.example/item?id=1          | news.example | no path        |
      | {site}/writing                          | no host      | /writing       |
      | {site}/writing/hello?ref=reddit         | no host      | /writing/hello |
      | {site}                                  | no host      | no path        |

  Scenario: A referrer past the cap is accepted and stored with no referrer
    When I send a beacon with a referrer of 2100 characters
    Then it answers 202
    And the database answers "1, no host" for:
      """
      SELECT count(*), coalesce(max(referrer_host), 'no host') FROM analytics_events
      """

  Scenario: The site is judged by the request's own host, not a forwarded one
    When I send a beacon with the header "X-Forwarded-Host" as "news.example":
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello", "referrer": "https://news.example/item"}
      """
    Then the database answers "news.example|no path" for:
      """
      SELECT coalesce(referrer_host, 'no host') || '|' || coalesce(referrer_path, 'no path') FROM analytics_events
      """

  Scenario: The site is judged by its host with the port removed
    When I send a beacon with the header "Host" as "127.0.0.1:8080":
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello", "referrer": "http://127.0.0.1/writing"}
      """
    Then the database answers "/writing" for:
      """
      SELECT referrer_path FROM analytics_events
      """

  Scenario Outline: A view with the ref <ref> stores the source <source>
    When I send a beacon:
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello", "ref": <ref>}
      """
    Then it answers 202
    And the database answers "<source>" for:
      """
      SELECT coalesce(source, 'none') FROM analytics_events
      """

    Examples:
      | ref                                   | source                           |
      | "reddit"                              | reddit                           |
      | "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"    | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa |
      | " Mastodon "                          | mastodon                         |
      | "news letter"                         | none                             |
      | "<b>x</b>"                            | none                             |
      | "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"   | none                             |
      | "  "                                  | none                             |
      | null                                  | none                             |

  Scenario: A view with no ref stores no source, and a blank title is kept as none
    When I send a beacon:
      """
      {"kind": "view", "path": "/writing/hello", "title": "   "}
      """
    Then the database answers "none, none" for:
      """
      SELECT coalesce(source, 'none') AS source, coalesce(title, 'none') AS title FROM analytics_events
      """

  Scenario Outline: A view from <browser> is stored as <class>, with no part of the user agent
    When I send a beacon as "<agent>":
      """
      {"kind": "view", "path": "/writing/hello", "view_token": "{token:first}"}
      """
    Then the database answers "<class>" for:
      """
      SELECT device_class FROM analytics_events
      """
    And the database answers "0" for:
      """
      SELECT count(*) FROM analytics_events WHERE row_to_json(analytics_events)::text ~ 'Mozilla|Chrome'
      """

    Examples:
      | browser                    | agent                                                                                                                                             | class   |
      | Chrome on a Mac            | Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36                                                                         | desktop |
      | Firefox on Windows         | Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:131.0) Firefox/131.0                                                                                 | desktop |
      | Safari on an iPhone        | Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1            | mobile  |
      | Chrome on an Android phone | Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Mobile Safari/537.36                              | mobile  |
      | Safari on an iPad          | Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1                     | tablet  |
      | Chrome on an Android tablet | Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36                                   | tablet  |
      | the Mastodon app           | Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Mastodon/2.6                         | in-app  |
      | the Bluesky app            | Mozilla/5.0 (Linux; Android 14; Pixel 8; wv) AppleWebKit/537.36 Version/4.0 Chrome/129.0.0.0 Mobile Safari/537.36 Bluesky/1.92                     | in-app  |
      | the Reddit app             | Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Reddit/Version_2024.40.0/Build_123   | in-app  |
      | the Facebook app           | Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 [FBAN/FBIOS;FBAV/480.0.0.0]         | in-app  |
      | the Instagram app          | Mozilla/5.0 (Linux; Android 14; Pixel 8; wv) AppleWebKit/537.36 Version/4.0 Chrome/129.0.0.0 Mobile Safari/537.36 Instagram 350.0.0.0 Android     | in-app  |
      | an Android web view        | Mozilla/5.0 (Linux; Android 14; Pixel 8; wv) AppleWebKit/537.36 Version/4.0 Chrome/129.0.0.0 Mobile Safari/537.36                                 | in-app  |
      | an iOS web view            | Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148                                      | in-app  |

  Scenario: Two browsers on one address count as two visitors in the night's rollup
    When I send a beacon:
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello"}
      """
    And I send a beacon as "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/130.0":
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello"}
      """
    And the visits move to yesterday
    And the analytics roll up
    Then the database soon answers "2" for:
      """
      SELECT visitors FROM analytics_rollups WHERE day = (now() AT TIME ZONE 'America/Chicago')::date - 1
      """

  Scenario: A read stores its time on the view, no second event, and raises it on a later read but never lowers it
    Given a reader viewed "/writing/hello" as "first"
    When I send a beacon:
      """
      {"kind": "read", "path": "/writing/hello", "read_seconds": 42, "view_token": "{token:first}"}
      """
    Then it answers 202
    And the database answers "1, 42" for:
      """
      SELECT count(*), max(read_seconds) FROM analytics_events
      """
    When I send a beacon:
      """
      {"kind": "read", "path": "/writing/hello", "read_seconds": 600, "view_token": "{token:first}"}
      """
    Then it answers 202
    And the database answers "600" for:
      """
      SELECT read_seconds FROM analytics_events
      """
    When I send a beacon:
      """
      {"kind": "read", "path": "/writing/hello", "read_seconds": 42, "view_token": "{token:first}"}
      """
    Then the database answers "600" for:
      """
      SELECT read_seconds FROM analytics_events
      """

  Scenario: A read past twenty minutes stores twenty minutes
    Given a reader viewed "/writing/hello" as "first"
    When I send a beacon:
      """
      {"kind": "read", "path": "/writing/hello", "read_seconds": 86400, "view_token": "{token:first}"}
      """
    Then the database answers "1200" for:
      """
      SELECT read_seconds FROM analytics_events
      """

  Scenario: A read stores the depth it carries and keeps the deeper one, and a depth the server does not take is turned away
    Given a reader viewed "/writing/hello" as "first"
    When I send a beacon:
      """
      {"kind": "read", "path": "/writing/hello", "read_seconds": 42, "scroll_depth": 75, "view_token": "{token:first}"}
      """
    And I send a beacon:
      """
      {"kind": "read", "path": "/writing/hello", "read_seconds": 60, "scroll_depth": 25, "view_token": "{token:first}"}
      """
    Then the database answers "60, 75" for:
      """
      SELECT read_seconds, scroll_depth FROM analytics_events
      """

  Scenario: A read with a depth the server does not take is turned away
    Given a reader viewed "/writing/hello" as "first"
    When I send a beacon:
      """
      {"kind": "read", "path": "/writing/hello", "read_seconds": 42, "scroll_depth": 30, "view_token": "{token:first}"}
      """
    Then it answers 400
    And the database answers "0, 0" for:
      """
      SELECT read_seconds, scroll_depth FROM analytics_events
      """

  Scenario: A read lands on the view its token names, and leaves another visitor's view alone
    Given a reader viewed "/writing/hello" as "first"
    And a reader viewed "/writing/hello" as "second"
    When I send a beacon as "Mozilla/5.0 Firefox/140.0":
      """
      {"kind": "read", "path": "/writing/hello", "read_seconds": 42, "view_token": "{token:first}"}
      """
    Then the database answers "0 0" for:
      """
      SELECT string_agg(read_seconds::text, ' ' ORDER BY id) FROM analytics_events
      """
    When I send a beacon:
      """
      {"kind": "read", "path": "/writing/hello", "read_seconds": 42, "view_token": "{token:first}"}
      """
    Then the database answers "42 0" for:
      """
      SELECT string_agg(read_seconds::text, ' ' ORDER BY id) FROM analytics_events
      """

  Scenario Outline: A read <how> is turned away with nothing to read
    Given a reader viewed "/writing/hello" as "first"
    When I send a beacon:
      """
      {"kind": "read", "path": "<path>", "read_seconds": 42, "view_token": "{token:<token>}"}
      """
    Then it answers 400
    And the answer is empty
    And the database answers "0" for:
      """
      SELECT max(read_seconds) FROM analytics_events
      """

    Examples:
      | how                                      | path           | token  |
      | under an unknown view token              | /writing/hello | second |
      | of a page the visitor never opened       | /about         | second |

  Scenario: A click on a post stores the link's host and path against the view, each time, with no second view
    Given a reader viewed "/writing/hello" as "first"
    When I send 2 beacons:
      """
      {"kind": "click", "path": "/writing/hello", "view_token": "{token:first}", "link_host": "docs.example", "link_path": "/guide"}
      """
    Then it answers 202
    And the database answers "2, docs.example, /guide, 1" for:
      """
      SELECT count(*) AS clicks, max(link_host) AS host, max(link_path) AS path, (SELECT count(*) FROM analytics_events) AS views
        FROM analytics_clicks JOIN analytics_events ON analytics_events.id = event_id
      """

  Scenario: A click under an unknown view token is turned away
    Given a reader viewed "/writing/hello" as "first"
    When I send a beacon:
      """
      {"kind": "click", "path": "/writing/hello", "view_token": "{token:second}", "link_host": "docs.example", "link_path": "/guide"}
      """
    Then it answers 400
    And the database answers "0" for:
      """
      SELECT count(*) FROM analytics_clicks
      """

  Scenario: A click past the cap on one view is throttled
    Given a reader viewed "/writing/hello" as "first"
    And the view "first" already has 50 clicks
    When I send a beacon:
      """
      {"kind": "click", "path": "/writing/hello", "view_token": "{token:first}", "link_host": "docs.example", "link_path": "/guide"}
      """
    Then it answers 429
    And the database answers "50" for:
      """
      SELECT count(*) FROM analytics_clicks
      """

  Scenario: Clicks on one view that arrive together stop at the cap, every one past it throttled
    Given a reader viewed "/writing/hello" as "first"
    And the view "first" already has 49 clicks
    When I send 5 beacons at once:
      """
      {"kind": "click", "path": "/writing/hello", "view_token": "{token:first}", "link_host": "docs.example", "link_path": "/guide"}
      """
    Then 1 of them were accepted and 4 throttled
    And the database answers "50" for:
      """
      SELECT count(*) FROM analytics_clicks
      """

  Scenario: A click stores nothing while the owner is signed in
    Given a reader viewed "/writing/hello" as "first"
    And I am signed in to the admin
    When I send a beacon:
      """
      {"kind": "click", "path": "/writing/hello", "view_token": "{token:first}", "link_host": "docs.example", "link_path": "/guide"}
      """
    Then the database answers "0" for:
      """
      SELECT count(*) FROM analytics_clicks
      """

  Scenario: A click under the token of a view of another page is turned away
    Given the posts:
      | title | slug  |
      | Other | other |
    And a reader viewed "/writing/other" as "other"
    When I send a beacon:
      """
      {"kind": "click", "path": "/writing/hello", "view_token": "{token:other}", "link_host": "docs.example", "link_path": "/guide"}
      """
    Then it answers 400
    And the database answers "0" for:
      """
      SELECT count(*) FROM analytics_clicks
      """

  Scenario Outline: A click on <page> is accepted and stores nothing
    Given a reader viewed "<path>" as "page"
    When I send a beacon:
      """
      {"kind": "click", "path": "<path>", "view_token": "{token:page}", "link_host": "docs.example", "link_path": "/guide"}
      """
    Then it answers 202
    And the database answers "0" for:
      """
      SELECT count(*) FROM analytics_clicks
      """

    Examples:
      | page              | path               |
      | the about page    | /about             |
      | the writing index | /writing           |
      | a tag page        | /writing/tags/ruby |

  Scenario Outline: A click <how> is turned away and stores nothing
    Given a reader viewed "/writing/hello" as "first"
    When I send a beacon:
      """
      {"kind": "click", "path": "/writing/hello", "view_token": "{token:first}", <link>}
      """
    Then it answers 400
    And the database answers "0" for:
      """
      SELECT count(*) FROM analytics_clicks
      """

    Examples:
      | how                          | link                                                     |
      | with no host                 | "link_path": "/guide"                                    |
      | with no path                 | "link_host": "docs.example"                              |
      | to a host that is no host    | "link_host": "docs.example/guide", "link_path": "/guide" |
      | to a host in capitals        | "link_host": "Docs.Example", "link_path": "/guide"       |
      | to a host past its cap       | "link_host": "LONGHOST", "link_path": "/guide"           |
      | carrying a query             | "link_host": "docs.example", "link_path": "/guide?token=secret" |
      | carrying a fragment          | "link_host": "docs.example", "link_path": "/guide#top"   |
      | to a path that is no path    | "link_host": "docs.example", "link_path": "guide"        |
      | to a path past its cap       | "link_host": "docs.example", "link_path": "LONGPATH"     |
      | carrying a control character | "link_host": "docs.example", "link_path": "/guide\u0001" |

  Scenario: A view starts at no depth, or at the depth the page showed when it loaded
    When I send a beacon:
      """
      {"kind": "view", "path": "/writing/hello", "view_token": "{token:first}"}
      """
    And I send a beacon:
      """
      {"kind": "view", "path": "/writing/hello", "view_token": "{token:second}", "scroll_depth": 100}
      """
    Then the database answers "0 100" for:
      """
      SELECT string_agg(scroll_depth::text, ' ' ORDER BY id) FROM analytics_events
      """

  Scenario: A scroll lands on the view it names, keeps the deeper depth, stores no event, and leaves another visitor alone
    Given a reader viewed "/writing/hello" as "first"
    And a reader viewed "/writing/hello" as "second"
    When I send a beacon as "Mozilla/5.0 Firefox/140.0":
      """
      {"kind": "scroll", "path": "/writing/hello", "scroll_depth": 50, "view_token": "{token:first}"}
      """
    Then the database answers "0 0" for:
      """
      SELECT string_agg(scroll_depth::text, ' ' ORDER BY id) FROM analytics_events
      """
    When I send a beacon:
      """
      {"kind": "scroll", "path": "/writing/hello", "scroll_depth": 75, "view_token": "{token:first}"}
      """
    And I send a beacon:
      """
      {"kind": "scroll", "path": "/writing/hello", "scroll_depth": 25, "view_token": "{token:first}"}
      """
    Then the database answers "75 0" for:
      """
      SELECT string_agg(scroll_depth::text, ' ' ORDER BY id) FROM analytics_events
      """

  Scenario Outline: A scroll <how> is turned away
    Given a reader viewed "/writing/hello" as "first"
    And a reader viewed "/writing/hello" as "second"
    When I send a beacon:
      """
      {"kind": "scroll", "path": "/writing/hello"<rest>}
      """
    Then it answers 400
    And the database answers "0 0" for:
      """
      SELECT string_agg(scroll_depth::text, ' ' ORDER BY id) FROM analytics_events
      """

    Examples:
      | how                         | rest                                                   |
      | with a depth of 30          | , "scroll_depth": 30, "view_token": "{token:first}"    |
      | with a depth of 0           | , "scroll_depth": 0, "view_token": "{token:first}"     |
      | with a depth of 125         | , "scroll_depth": 125, "view_token": "{token:first}"   |
      | with no depth               | , "view_token": "{token:first}"                        |
      | with no view token          | , "scroll_depth": 50                                   |
      | of a view never stored      | , "scroll_depth": 50, "view_token": "{token:never}"    |

  Scenario: A view is accepted but stored nowhere while the owner is signed in
    Given I am signed in to the admin
    When I send a beacon:
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello"}
      """
    Then it answers 202
    And the database answers "0" for:
      """
      SELECT count(*) FROM analytics_events
      """

  Scenario: A view from a known bot, or a client with no user agent, is stored nowhere
    When I send a beacon as "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)":
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello"}
      """
    And I send a beacon with no user agent:
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello"}
      """
    Then the database answers "0" for:
      """
      SELECT count(*) FROM analytics_events
      """

  Scenario Outline: A view of <what> is turned away and stores nothing
    When I send a beacon:
      """
      {"kind": "view", "path": <path>, "title": "Sign in"}
      """
    Then it answers 400
    And the database answers "0" for:
      """
      SELECT count(*) FROM analytics_events
      """

    Examples:
      | what                             | path                             |
      | a path that names no page        | "/wp-login.php"                  |
      | a path under the admin           | "/admin/posts"                   |
      | a path the beacon only posts to  | "/pulse"                         |
      | a path that is not rooted        | "writing/hello"                  |
      | a path pointing at another site  | "//evil.example"                 |
      | a path carrying a query          | "/writing/hello?utm_source=spam" |
      | a path carrying a fragment       | "/writing/hello#spam"            |
      | a path no URL can hold           | "/%"                             |
      | a path that is not a string      | null                             |
      | an empty path                    | ""                               |

  Scenario Outline: A view of <path> is accepted and stored
    When I send a beacon:
      """
      {"kind": "view", "path": "<path>"}
      """
    Then it answers 202
    And the database answers "<path>" for:
      """
      SELECT path FROM analytics_events
      """

    Examples:
      | path               |
      | /                  |
      | /about             |
      | /contact           |
      | /privacy           |
      | /projects          |
      | /writing           |
      | /writing/hello     |
      | /writing/tags/ruby |

  Scenario: A view of a tag only a project carries is stored
    Given the projects:
      | name | tags |
      | sai  | go   |
    When I send a beacon:
      """
      {"kind": "view", "path": "/writing/tags/go"}
      """
    Then the database answers "/writing/tags/go" for:
      """
      SELECT path FROM analytics_events
      """

  Scenario Outline: A view of <what> on a published board is stored
    Given the projects:
      | name     | board     |
      | Doing It | published |
    And the tasks of the project "Doing It":
      | title |
      | One   |
    When I send a beacon:
      """
      {"kind": "view", "path": "<path>"}
      """
    Then the database answers "<path>" for:
      """
      SELECT path FROM analytics_events
      """

    Examples:
      | what   | path                       |
      | the board | /projects/doing-it      |
      | a task | /projects/doing-it/tasks/1 |

  Scenario Outline: A view of <what> stores nothing
    Given the projects:
      | name     | board     | visibility |
      | Doing It | published |            |
      | hello    | published | private    |
    And the tasks of the project "Doing It":
      | title |
      | One   |
    When I send a beacon:
      """
      {"kind": "view", "path": "<path>"}
      """
    Then the database answers "0" for:
      """
      SELECT count(*) FROM analytics_events
      """

    Examples:
      | what                                                      | path                         |
      | a board no project has                                    | /projects/nothing-here       |
      | a task the board does not hold                            | /projects/doing-it/tasks/2   |
      | a task number no task can take                            | /projects/doing-it/tasks/abc |
      | a board slug that decodes to bad UTF-8                    | /projects/%FF                |
      | a private board whose slug a published post shares        | /projects/hello              |

  Scenario: A view of a public project whose board is unpublished, its slug shared by a post, stores nothing
    Given the projects:
      | name  |
      | hello |
    When I send a beacon:
      """
      {"kind": "view", "path": "/projects/hello"}
      """
    Then the database answers "0" for:
      """
      SELECT count(*) FROM analytics_events
      """

  Scenario Outline: A view of <what>, which the router answers but which names nothing, is accepted and stored nowhere
    Given the posts:
      | title      | status | tags   |
      | Unfinished | draft  | secret |
    When I send a beacon:
      """
      {"kind": "view", "path": "<path>"}
      """
    Then it answers 202
    And the database answers "0" for:
      """
      SELECT count(*) FROM analytics_events
      """

    Examples:
      | what                                | path                       |
      | a post that does not exist          | /writing/nothing-here      |
      | a draft                             | /writing/unfinished        |
      | a slug no post can take             | /writing/Not%20A%20Slug    |
      | a slug that decodes to bad UTF-8    | /writing/%FF               |
      | a tag that does not exist           | /writing/tags/nothing-here |
      | a tag only a draft carries          | /writing/tags/secret       |
      | a tag in another case than its own  | /writing/tags/Ruby         |
      | a tag that decodes to bad UTF-8     | /writing/tags/%FF          |
      | a media file                        | /media/made-up-key         |
      | the manifest                        | /site.webmanifest          |
      | the writing feed                    | /writing.atom              |
      | a tag's feed                        | /writing/tags/ruby.atom    |

  Scenario: A malformed beacon for a page that names nothing is turned away as it would be for a real page
    When I send a beacon:
      """
      {"kind": "click", "path": "/writing/nothing-here"}
      """
    Then it answers 400

  Scenario Outline: <what> for a post that does not exist is accepted, and for a post never viewed turned away
    When I send a beacon:
      """
      {"path": "/writing/nothing-here", "view_token": "{token:first}", <rest>}
      """
    Then it answers 202
    When I send a beacon:
      """
      {"path": "/writing/hello", "view_token": "{token:never}", <rest>}
      """
    Then it answers 400

    Examples:
      | what     | rest                                                              |
      | A read   | "kind": "read", "read_seconds": 42                                |
      | A scroll | "kind": "scroll", "scroll_depth": 50                              |
      | A click  | "kind": "click", "link_host": "docs.example", "link_path": "/guide" |

  Scenario Outline: A beacon another site's page sent, <how>, is refused and stores nothing
    When I send a beacon with the header "<header>" as "<value>":
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello"}
      """
    Then it answers 403
    And the database answers "0" for:
      """
      SELECT count(*) FROM analytics_events
      """

    Examples:
      | how                                    | header         | value                |
      | which the browser marks cross-site     | Sec-Fetch-Site | cross-site           |
      | which the browser marks same-site      | Sec-Fetch-Site | same-site            |
      | from a browser naming another origin   | Origin         | https://evil.example |
      | from a browser naming a null origin    | Origin         | null                 |

  Scenario Outline: A beacon the site's own page sent, <how>, is stored
    Given my requests send <headers>
    When I send a beacon:
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello"}
      """
    Then it answers 202
    And the database answers "1" for:
      """
      SELECT count(*) FROM analytics_events
      """

    Examples:
      | how                                          | headers                                      |
      | which the browser marks same-origin          | the header "Sec-Fetch-Site" as "same-origin" |
      | which the browser marks as asked for by none | the header "Sec-Fetch-Site" as "none"        |
      | from a browser naming the site's origin      | the header "Origin" as "{site}"              |
      | from a client that sends neither header      | no "Origin" header                           |

  Scenario: The browser's mark is trusted over an origin it does not name
    Given my requests send the header "Sec-Fetch-Site" as "same-origin"
    And my requests send the header "Origin" as "https://pi.local"
    When I send a beacon:
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello"}
      """
    Then the database answers "1" for:
      """
      SELECT count(*) FROM analytics_events
      """

  @timeout:180_000
  Scenario: In production a run of views past the limit is refused with nothing to read, a new browser on each or not
    Given the environment sets ANALYTICS_THROTTLE_LIMIT to "5"
    And the site runs in production
    When I send 6 beacons with the browsers "Mozilla/5.0 xN":
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello"}
      """
    Then it answers 429
    And the answer is empty
    And the database answers "5" for:
      """
      SELECT count(*) FROM analytics_events
      """

  @timeout:180_000
  Scenario: In production a run past the limit from one IPv6 /64 is refused, its address hash keyed on the network
    Given the environment sets ANALYTICS_THROTTLE_LIMIT to "5"
    And the site runs in production
    When I send 6 beacons from the addresses "2001:db8:1:2::N":
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello"}
      """
    Then it answers 429
    And the database answers "5, 1" for:
      """
      SELECT count(*) AS views, count(DISTINCT address_hash) AS networks FROM analytics_events
      """
    When I send 1 beacon from the addresses "2001:db8:1:3::1":
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello"}
      """
    Then it answers 202

  @timeout:180_000
  Scenario Outline: In production a <kind> from an address that has reached the limit is refused and stores nothing
    Given the environment sets ANALYTICS_THROTTLE_LIMIT to "2"
    And the site runs in production
    And a reader viewed "/writing/hello" as "first"
    And a reader viewed "/writing/hello" as "second"
    When I send a beacon:
      """
      {"kind": "<kind>", "path": "/writing/hello", "view_token": "{token:first}", <rest>}
      """
    Then it answers 429
    And the database answers "0 0" for:
      """
      SELECT string_agg(<column>::text, ' ' ORDER BY id) FROM analytics_events
      """

    Examples:
      | kind   | rest                 | column       |
      | read   | "read_seconds": 42   | read_seconds |
      | scroll | "scroll_depth": 50   | scroll_depth |

  @timeout:180_000
  Scenario: In production views from one address that arrive together stop at the limit, every one past it throttled
    Given the environment sets ANALYTICS_THROTTLE_LIMIT to "3"
    And the site runs in production
    When I send 5 beacons at once:
      """
      {"kind": "view", "path": "/writing/hello", "view_token": "{token:view-{n}}"}
      """
    Then 3 of them were accepted and 2 throttled
    And the database answers "3" for:
      """
      SELECT count(*) FROM analytics_events
      """

  @timeout:180_000
  Scenario Outline: In production past the limit, <what> for a post that does not exist is still accepted and stored nowhere
    Given the environment sets ANALYTICS_THROTTLE_LIMIT to "1"
    And the site runs in production
    When I send 2 beacons:
      """
      {"kind": "view", "path": "/writing/hello", "title": "Hello"}
      """
    And I send a beacon:
      """
      {"path": "/writing/nothing-here", "view_token": "{token:first}", <rest>}
      """
    Then it answers 202
    And the database answers "1" for:
      """
      SELECT count(*) FROM analytics_events
      """

    Examples:
      | what     | rest                                                              |
      | a view   | "kind": "view"                                                    |
      | a read   | "kind": "read", "read_seconds": 42                                |
      | a scroll | "kind": "scroll", "scroll_depth": 50                              |
      | a click  | "kind": "click", "link_host": "docs.example", "link_path": "/guide" |

  Scenario Outline: A body that is <what> is rejected with nothing to read
    When I post "/pulse" with the "application/json" body "<body>"
    Then it answers 400
    And the answer is empty

    Examples:
      | what     | body      |
      | not JSON | kind=view |
      | empty    |           |

  Scenario Outline: A payload <what> is rejected and stores nothing
    When I send a beacon:
      """
      <json>
      """
    Then it answers 400
    And the database answers "0" for:
      """
      SELECT count(*) FROM analytics_events
      """

    Examples:
      | what                              | json                                                                 |
      | that is a JSON array              | [{"kind": "view", "path": "/writing/hello"}]                         |
      | that is a JSON string             | "view"                                                               |
      | of an unknown kind                | {"kind": "share", "path": "/writing/hello"}                          |
      | with a path past its cap          | {"kind": "view", "path": "/writing/LONGPATH"}                        |
      | with a title past its cap         | {"kind": "view", "path": "/writing/hello", "title": "LONGTITLE"}     |
      | of a read with no time            | {"kind": "read", "path": "/writing/hello", "view_token": "{token:first}"} |
      | of a read naming no view          | {"kind": "read", "path": "/writing/hello", "read_seconds": 42}       |
      | with a view token that is no token | {"kind": "view", "path": "/writing/hello", "view_token": "not-a-token"} |
      | with a NUL byte in the path       | {"kind": "view", "path": "/writing/hello\u0000"}                     |
      | with a NUL byte in the title      | {"kind": "view", "path": "/writing/hello", "title": "Hello\u0000"}   |
      | with a control character in the title | {"kind": "view", "path": "/writing/hello", "title": "Hello\u0001"} |

  Scenario: A body too big to be a visit is refused, with or without a stated length, and one at the cap is taken
    When I send a beacon:
      """
      {"kind": "view", "path": "/BIGPATH"}
      """
    Then it answers 413
    When I send a beacon with no stated length:
      """
      {"kind": "view", "path": "/BIGPATH"}
      """
    Then it answers 413
    When I send a beacon at the cap
    Then it answers 202

  Scenario: The beacon answers only to POST
    When I request "/pulse"
    Then it answers 405

  Scenario Outline: The beacon loads on <path>, capped to the server's read time and depths, counting no clicks
    When I visit "<path>"
    Then the page has "body[data-beacon='/pulse'][data-beacon-read-cap='1200'][data-beacon-depths='25 50 75 100']"
    And the page has no "body[data-beacon-clicks]"

    Examples:
      | path               |
      | /                  |
      | /about             |
      | /contact           |
      | /projects          |
      | /writing           |
      | /writing/tags/ruby |

  Scenario: The beacon counts clicks on a post
    When I visit "/writing/hello"
    Then the page has "body[data-beacon-clicks]"

  Scenario Outline: <place> loads no script or sheet from another site
    Given <signed in>
    When I visit "<path>"
    Then every script and sheet on the page loads from the site

    Examples:
      | place             | signed in                   | path     |
      | The home page     | I am not signed in          | /        |
      | The writing index | I am not signed in          | /writing |
      | The admin         | I am signed in to the admin | /admin   |

  Scenario: The beacon stays off the admin
    Given I am signed in to the admin
    When I visit "/admin"
    Then the page has no "body[data-beacon]"
