Feature: Counting feed readers
  Each day the site counts the readers that fetch each feed once, and keeps the
  subscriber count an aggregator names in its user agent.

  Background:
    Given these analytics posts:
      | slug  | published | tags |
      | hello | today-30  | ruby |

  Scenario Outline: An aggregator that names its subscribers has its count kept for the day
    When "<agent>" fetches the feed "/writing.atom"
    Then the feed_subscribers rows are:
      | day   | path          | aggregator   | subscribers |
      | today | /writing.atom | <aggregator> | 42          |
    And the feed_readers table holds 0 rows

    Examples:
      | agent                                                                           | aggregator |
      | Feedly/1.0 (+https://feedly.com/poller.html; 42 subscribers; )                  | feedly     |
      | Mozilla/5.0 (compatible; Inoreader/1.0; https://www.inoreader.com; 42 subscribers) | inoreader  |
      | NewsBlur Feed Fetcher - 42 subscribers - https://www.newsblur.com/site/1/hello  | newsblur   |

  Scenario: An aggregator keeps the later count of two on one day and one count a day
    Given these feed_subscribers rows:
      | day     | aggregator | subscribers |
      | today-1 | feedly     | 41          |
    When "Feedly/1.0 (+https://feedly.com/poller.html; 42 subscribers; )" fetches the feed "/writing.atom"
    And "Feedly/1.0 (+https://feedly.com/poller.html; 40 subscribers; )" fetches the feed "/writing.atom"
    Then the feed_subscribers rows are:
      | day     | aggregator | subscribers |
      | today-1 | feedly     | 41          |
      | today   | feedly     | 40          |

  Scenario: An aggregator's count is kept apart for each feed
    When "Feedly/1.0 (42 subscribers)" fetches the feed "/writing.atom"
    And "Feedly/1.0 (7 subscribers)" fetches the feed "/writing/tags/ruby.atom"
    Then the feed_subscribers rows are:
      | path                    | subscribers |
      | /writing.atom           | 42          |
      | /writing/tags/ruby.atom | 7           |

  Scenario: An aggregator's fetch that gets a 304 still counts
    When "NetNewsWire" fetches the feed "/writing.atom"
    And "Feedly/1.0 (42 subscribers)" fetches the feed "/writing.atom" again unchanged
    Then the server answered 304
    And the feed_subscribers rows are:
      | subscribers |
      | 42          |

  Scenario: A feed reader counts once a day however often it fetches
    Given these feed_readers rows:
      | day     | readers |
      | today-1 | 1       |
    When "NetNewsWire" fetches the feed "/writing.atom"
    And "NetNewsWire" fetches the feed "/writing.atom"
    And "NetNewsWire" fetches the feed "/writing.atom"
    Then the feed_readers rows are:
      | day     | path          | readers |
      | today-1 | /writing.atom | 1       |
      | today   | /writing.atom | 1       |
    And the feed_reader_hashes table holds 1 rows where "reader_hash ~ '^[0-9a-f]{64}$'"
    And the feed_reader_hashes table has the columns "day, path, reader_hash"

  Scenario: Two feed readers count as two, a 304 included
    When "NetNewsWire" fetches the feed "/writing.atom"
    And "Firefox" fetches the feed "/writing.atom" again unchanged
    Then the server answered 304
    And the feed_readers rows are:
      | readers |
      | 2       |

  Scenario: A feed reader counts once in each feed it fetches
    When "NetNewsWire" fetches the feed "/writing.atom"
    And "NetNewsWire" fetches the feed "/writing/tags/ruby.atom"
    Then the feed_readers rows are:
      | path                    | readers |
      | /writing.atom           | 1       |
      | /writing/tags/ruby.atom | 1       |

  Scenario: A tag feed fetched in another case counts once under its own path
    When "NetNewsWire" fetches the feed "/writing/tags/Ruby.atom"
    And "NetNewsWire" follows the feed move
    Then the feed_readers rows are:
      | path                    | readers |
      | /writing/tags/ruby.atom | 1       |

  Scenario Outline: An agent that names no count the site knows counts as a reader
    When "<agent>" fetches the feed "/writing.atom"
    And "<agent>" fetches the feed "/writing.atom"
    Then the feed_readers rows are:
      | readers |
      | 1       |
    And the feed_subscribers table holds 0 rows

    Examples:
      | agent                                                                  |
      | Feedly/1.0 (+http://www.feedly.com/fetcher.html; like FeedFetcher-Google) |
      | Feedbin feed-id:1234 - 42 subscribers                                  |
      | Mozilla/5.0 (compatible; Bazqux/2.0; 42 subscribers)                   |
      | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa - 42 subscribers                     |
      | 42 subscribers                                                         |
      | Feedly/1.0 (12345678901 subscribers)                                   |

  Scenario: The site makes up no aggregator from an agent's name
    When "Mozilla/5.0 (compatible; alpha/1.0; 42 subscribers)" fetches the feed "/writing.atom"
    And "Mozilla/5.0 (compatible; beta/1.0; 42 subscribers)" fetches the feed "/writing.atom"
    And "Mozilla/5.0 (compatible; gamma/1.0; 42 subscribers)" fetches the feed "/writing.atom"
    Then the feed_subscribers table holds 0 rows

  Scenario: A signed in fetch counts nothing
    Given I am signed in to the admin
    When "NetNewsWire" fetches the feed "/writing.atom"
    And "Feedly/1.0 (42 subscribers)" fetches the feed "/writing.atom"
    Then the feed_readers table holds 0 rows
    And the feed_subscribers table holds 0 rows

  Scenario Outline: A fetch that finds no feed counts nothing
    When "NetNewsWire" fetches the feed "<path>"
    Then the feed_readers table holds 0 rows

    Examples:
      | path                       |
      | /writing/tags/nothing.atom |
      | /writing/tags/Ruby.atom    |
      | /writing.atom?page=9       |

  Scenario: The roll up prunes old feed hashes and leaves the daily count in place
    When "NetNewsWire" fetches the feed "/writing.atom"
    And the feed reader hashes are dated "today-91"
    And the job "Analytics::Jobs::RollUpAnalytics" runs
    Then the feed_reader_hashes table holds 0 rows
    And the feed_readers rows are:
      | readers |
      | 1       |
