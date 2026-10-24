Feature: Feeds
  /writing.atom and each tag's feed carry the newest 25 published posts as valid Atom, 25 to a page, with the
  rendered body and its edit notes. They name the site setting whatever host asked, and answer a reader polling
  with the ETag or the time a 304 until something on the page changes.

  Scenario: The writing feed serves valid Atom, with posts or none
    When I request "/writing.atom"
    Then the XML answer passes the schema "atom.rng"
    Given the posts:
      | title | tags | body                                         |
      | Hello | ruby | the <start> & more\n\n```ruby\nputs 1\n```   |
    When I request "/writing.atom"
    Then the "Content-Type" header is "application/atom+xml; charset=utf-8"
    And the XML answer passes the schema "atom.rng"

  Scenario Outline: The writing feed serves Atom to <who>
    Given my requests send the header "Accept" as "<accept>"
    When I request "/writing.atom"
    Then it answers 200
    And the "Content-Type" header is "application/atom+xml; charset=utf-8"

    Examples:
      | who                                | accept                                                            |
      | a reader that asks for it          | application/atom+xml                                              |
      | a reader that takes anything       | */*                                                               |
      | a browser                          | text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8   |
      | a reader that asks for RSS or XML  | application/rss+xml, application/xml;q=0.9                        |
      | a reader that asks for text/xml    | text/xml                                                          |

  Scenario: The writing feed lists only published posts, newest first, and names itself, its page and its author
    Given the posts:
      | title | tags            | published     | status    |
      | Older | anything        | 3 minutes ago |           |
      | Newer | hanami, anything | 2 minutes ago |           |
      | Other | rust            | 1 minute ago  |           |
      | Draft | anything        |               | draft     |
      | Later | anything        | in 1 day      | scheduled |
    When I request "/writing.atom"
    Then the XML answer's "/feed/entry/id" are:
      | {site}/writing/other |
      | {site}/writing/newer |
      | {site}/writing/older |
    And the XML answer's "/feed/title" is "Writing | Aaron Allen"
    And the XML answer's "/feed/id" is "{site}/writing"
    And the XML answer's "/feed/author/name" is "Aaron Allen"
    And the XML answer's "/feed/link[@rel='alternate']/@href" is "{site}/writing"
    And the XML answer's "/feed/link[@rel='self']/@href" is "{site}/writing.atom"

  Scenario: The feed's updated time is the latest post change, kept after the post's webmentions send
    Given the posts:
      | title | published            | updated              | body                                   |
      | One   | 2026-09-01T00:00:00Z | 2026-09-09T00:00:00Z | [a note](http://203.0.113.5/notes/1)   |
      | Two   | 2026-09-05T00:00:00Z | 2026-09-05T00:00:00Z |                                        |
    When I request "/writing.atom"
    Then the XML answer's "/feed/updated" is "2026-09-09T00:00:00Z"
    When the post "One" sends its webmentions
    And I request "/writing.atom"
    Then the XML answer's "/feed/updated" is "2026-09-09T00:00:00Z"

  Scenario: An entry has its title, a link tagged as from the feed, its id, times, categories, summary and body
    Given the posts:
      | title | tags         | published            | updated              | body                        |
      | Hello | ruby, hanami | 2026-09-07T12:00:00Z | 2026-09-07T12:01:00Z | the *start*\n\nthe rest     |
    When I request "/writing.atom"
    Then the XML answer's "/feed/entry/title" is "Hello"
    And the XML answer's "/feed/entry/link[@rel='alternate']/@href" is "{site}/writing/hello?ref=feed"
    And the XML answer's "/feed/entry/id" is "{site}/writing/hello"
    And the XML answer's "/feed/entry/published" is "2026-09-07T12:00:00Z"
    And the XML answer's "/feed/entry/updated" is "2026-09-07T12:01:00Z"
    And the XML answer's "/feed/entry/category/@term" are:
      | hanami |
      | ruby   |
    And the XML answer's "/feed/entry/summary" is "the start"
    And the XML answer's "/feed/entry/content[@type='html']" is "<p>the <em>start</em></p>\n<p>the rest</p>\n"

  Scenario: An entry's body gives its headings the ids the article does
    Given the posts:
      | title  | body          |
      | Headed | ## The Setup  |
    When I request "/writing.atom"
    Then the XML answer's "/feed/entry/content" include "<h2 id=\"the-setup\">The Setup</h2>\n"

  Scenario: An entry carries the summary the post has, and leaves it out when the body has no paragraph
    Given the posts:
      | title   | summary          | body              | published     |
      | Summed  | What it is about | the start         | 1 minute ago  |
      | Heading |                  | ## Only a heading | 2 minutes ago |
    When I request "/writing.atom"
    Then the XML answer's "/feed/entry[title='Summed']/summary" is "What it is about"
    And the XML answer has no "/feed/entry[title='Heading']/summary"

  Scenario: An entry escapes markup in its title and body
    Given the posts:
      | title               | body                                |
      | <b>bold</b> & more  | a <script>alert(1)</script> & b     |
    When I request "/writing.atom"
    Then the XML answer's "/feed/entry/title" is "<b>bold</b> & more"
    And the XML answer's "/feed/entry/content" do not include "<script>"
    And the body does not include "<script>"

  Scenario: An entry with an edit note ends with the note after the body, dated by the site's day
    Given the posts:
      | title | body      |
      | Hello | the start |
    And the post "Hello" carries the edit notes:
      | note           | at                   |
      | late night fix | 2026-09-08T03:00:00Z |
    When I request "/writing.atom"
    Then the feed entry's content for "Hello" holds the tags "p, section"
    And the feed entry's content for "Hello" reads "Edited Sep 7, 2026 late night fix" at ".post-edit"
    And the XML answer passes the schema "atom.rng"

  Scenario: An entry with notes from two days shows each date once, newest first, a day's notes oldest first
    Given the posts:
      | title | body      |
      | Hello | the start |
    And the post "Hello" carries the edit notes:
      | note              | at                   |
      | fixed the numbers | 2026-09-07T12:00:00Z |
      | fixed a link      | 2026-09-07T15:00:00Z |
      | fixed a typo      | 2026-09-09T12:00:00Z |
    When I request "/writing.atom"
    Then the feed entry's content for "Hello" reads "Edited Sep 9, 2026, Edited Sep 7, 2026" at ".post-edit-date"
    And the feed entry's content for "Hello" reads "fixed the numbers, fixed a link" at ".post-edit-item"
    And the feed entry's content for "Hello" reads "fixed a typo" at ".post-edit-note"

  Scenario: A note's Markdown renders in the feed and its raw HTML is escaped, and another post's entry has no notes
    Given the posts:
      | title | body      | published     |
      | Hello | the start | 2 minutes ago |
      | Other | the other | 1 minute ago  |
    And the post "Hello" carries the edit notes:
      | note                                                                   | at                   |
      | fixed `count` and [the link](https://example.com/docs) and <script>x</script> | 2026-09-07T12:00:00Z |
    When I request "/writing.atom"
    Then the feed entry's content for "Hello" reads "count" at ".post-edit-note code"
    And the feed entry's content for "Hello" reads "the link" at ".post-edit-note a[href='https://example.com/docs']"
    And the feed entry's content for "Hello" has no ".post-edit-note script"
    And the XML answer's "/feed/entry[title='Other']/content" is "<p>the other</p>\n"

  Scenario: A tag feed serves valid Atom with only the tag's published posts, newest first
    Given the posts:
      | title | tags         | published     | status    |
      | Older | ruby         | 3 minutes ago |           |
      | Newer | hanami, ruby | 2 minutes ago |           |
      | Other | rust         | 1 minute ago  |           |
      | Draft | ruby         |               | draft     |
      | Later | ruby         | in 1 day      | scheduled |
    When I request "/writing/tags/ruby.atom"
    Then the "Content-Type" header is "application/atom+xml; charset=utf-8"
    And the XML answer passes the schema "atom.rng"
    And the XML answer's "/feed/entry/id" are:
      | {site}/writing/newer |
      | {site}/writing/older |
    And the XML answer's "/feed/title" is "Writing tagged ruby | Aaron Allen"
    And the XML answer's "/feed/id" is "{site}/writing/tags/ruby"
    And the XML answer's "/feed/link[@rel='self']/@href" is "{site}/writing/tags/ruby.atom"

  Scenario Outline: A tag feed serves Atom to <who>
    Given the posts:
      | title | tags |
      | Hello | ruby |
    And my requests send the header "Accept" as "<accept>"
    When I request "/writing/tags/ruby.atom"
    Then it answers 200
    And the "Content-Type" header is "application/atom+xml; charset=utf-8"

    Examples:
      | who                       | accept                                                          |
      | a reader that asks for it | application/atom+xml                                            |
      | a browser                 | text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8 |

  Scenario: A tag feed finds a tag with a dash, moves another spelling to its own feed keeping the page, and 404s the rest
    Given the posts:
      | title  | tags        | status |
      | Hello  | open-source |        |
      | Ruby   | ruby        |        |
      | Secret | secret      | draft  |
    When I request "/writing/tags/open-source.atom"
    Then the XML answer's "/feed/entry/id" are:
      | {site}/writing/hello |
    When I request "/writing/tags/RUBY.atom"
    Then it answers 301
    And the "Location" header is "/writing/tags/ruby.atom"
    When I request "/writing/tags/Ruby.atom?page=2"
    Then the "Location" header is "/writing/tags/ruby.atom?page=2"
    When I request "/writing/tags/open%20source.atom"
    Then it answers 404
    When I request "/writing/tags/secret.atom"
    Then it answers 404

  Scenario: The feed carries the newest 25 posts
    Given 26 published posts
    When I request "/writing.atom"
    Then the XML answer's "count(/feed/entry)" is "25"
    And the XML answer's "/feed/entry[1]/id" is "{site}/writing/post-1"
    And the XML answer's "/feed/entry[25]/id" is "{site}/writing/post-25"

  Scenario Outline: <path> pages 25 at a time, linking older and newer pages under one feed id
    Given 55 published posts tagged "ruby"
    When I request "<path>"
    Then the XML answer's "count(/feed/entry)" is "25"
    And the XML answer's "/feed/entry[1]/id" is "{site}/writing/post-1"
    And the feed links are "self <atom>, alternate <html>, next <atom>?page=2"
    When I request "<path>?page=2"
    Then the XML answer's "/feed/entry[1]/id" is "{site}/writing/post-26"
    And the feed links are "self <atom>?page=2, alternate <html>?page=2, next <atom>?page=3, previous <atom>"
    And the XML answer's "/feed/id" is "<html>"
    And the XML answer passes the schema "atom.rng"
    When I request "<path>?page=3"
    Then the XML answer's "count(/feed/entry)" is "5"
    And the feed links are "self <atom>?page=3, alternate <html>?page=3, previous <atom>?page=2"
    When I request "<path>?page=4"
    Then it answers 404
    When I request "<path>?page=two"
    Then it answers 404

    Examples:
      | path                    | atom                           | html                      |
      | /writing.atom           | {site}/writing.atom            | {site}/writing            |
      | /writing/tags/ruby.atom | {site}/writing/tags/ruby.atom  | {site}/writing/tags/ruby  |

  Scenario Outline: <path> links no other page when one page holds every post
    Given 25 published posts tagged "ruby"
    When I request "<path>"
    Then the XML answer has no "/feed/link[@rel='next' or @rel='previous']"

    Examples:
      | path                    |
      | /writing.atom           |
      | /writing/tags/ruby.atom |

  Scenario: The feed names the newest post change as its time and tags itself with a weak ETag
    Given the posts:
      | title | tags         | published      | updated        |
      | Older | ruby         | 25 hours ago   | 25 hours ago   |
      | Hello | hanami, ruby | 1 day ago      | 1 day ago      |
    When I request "/writing.atom"
    Then the "Last-Modified" header is the time the post "Hello" last changed
    And the "ETag" header matches the pattern "^W/\"[0-9a-f]{64}\"$"

  Scenario Outline: <path> answers 304 with no body while nothing changes, repeating the ETag and Vary
    Given the posts:
      | title | tags         | published    | updated      |
      | Older | ruby         | 25 hours ago | 25 hours ago |
      | Hello | hanami, ruby | 1 day ago    | 1 day ago    |
    When I request "<path>"
    And I keep the feed's ETag and time
    And I poll "<path>" with the time
    Then it answers 304
    And the body is:
      """
      """
    When I poll "<path>" with the ETag
    Then it answers 304
    And the body is:
      """
      """
    When I poll "<path>" with the ETag and the time
    Then the ETag and Vary on the 304 are the ones the feed gave

    Examples:
      | path                    |
      | /writing.atom           |
      | /writing/tags/ruby.atom |

  Scenario Outline: <path> answers 200 to a poll once <change>
    Given the posts:
      | title | tags         | published    | updated      |
      | Older | ruby         | 25 hours ago | 25 hours ago |
      | Hello | hanami, ruby | 1 day ago    | 1 day ago    |
    When I request "<path>"
    And I keep the feed's ETag and time
    And the database runs:
      """
      <statement>
      """
    And I poll "<path>" with <sent>
    Then it answers 200
    And the XML answer's "<xpath>" <check> "<value>"

    Examples:
      | path                    | change                                       | statement                                                                                                                                   | sent                   | xpath                                    | check          | value                  |
      | /writing.atom           | another post is published                    | INSERT INTO posts (title, slug, status, published_at, body, body_html, read_time, word_count, webmentions_enabled) SELECT 'Newest', 'newest', 'published', now(), 'x', '<p>x</p>', 1, 1, false; INSERT INTO post_tags (post_id, tag_id) SELECT posts.id, tags.id FROM posts, tags WHERE slug = 'newest' AND tags.name = 'ruby' | the ETag and the time | /feed/entry[1]/id                        | is             | {site}/writing/newest  |
      | /writing/tags/ruby.atom | another post is published                    | INSERT INTO posts (title, slug, status, published_at, body, body_html, read_time, word_count, webmentions_enabled) SELECT 'Newest', 'newest', 'published', now(), 'x', '<p>x</p>', 1, 1, false; INSERT INTO post_tags (post_id, tag_id) SELECT posts.id, tags.id FROM posts, tags WHERE slug = 'newest' AND tags.name = 'ruby' | the ETag and the time | /feed/entry[1]/id                        | is             | {site}/writing/newest  |
      | /writing.atom           | a post changes                               | UPDATE posts SET title = 'Revised', updated_at = now() WHERE slug = 'older'                                                                 | the ETag and the time | /feed/entry/title                        | include        | Revised                |
      | /writing/tags/ruby.atom | a post changes                               | UPDATE posts SET title = 'Revised', updated_at = now() WHERE slug = 'older'                                                                 | the ETag and the time | /feed/entry/title                        | include        | Revised                |
      | /writing.atom           | a post is deleted                            | DELETE FROM posts WHERE slug = 'older'                                                                                                      | the ETag and the time | /feed/entry/id                           | do not include | {site}/writing/older   |
      | /writing/tags/ruby.atom | a post is deleted                            | DELETE FROM posts WHERE slug = 'older'                                                                                                      | the ETag and the time | /feed/entry/id                           | do not include | {site}/writing/older   |
      | /writing.atom           | a post is deleted, polled with the time      | DELETE FROM posts WHERE slug = 'older'                                                                                                      | the time              | /feed/entry/id                           | do not include | {site}/writing/older   |
      | /writing/tags/ruby.atom | a post is deleted, polled with the time      | DELETE FROM posts WHERE slug = 'older'                                                                                                      | the time              | /feed/entry/id                           | do not include | {site}/writing/older   |
      | /writing.atom           | a tag on the page is renamed                 | UPDATE tags SET name = 'rails', updated_at = now() WHERE name = 'hanami'                                                                                        | the ETag              | /feed/entry/category/@term               | include        | rails                  |
      | /writing/tags/ruby.atom | a tag on the page is renamed                 | UPDATE tags SET name = 'rails', updated_at = now() WHERE name = 'hanami'                                                                                        | the ETag              | /feed/entry/category/@term               | include        | rails                  |
      | /writing.atom           | a tag on the page is renamed, polled with the time | UPDATE tags SET name = 'rails', updated_at = now() WHERE name = 'hanami'                                                                                  | the time              | /feed/entry/category/@term               | include        | rails                  |
      | /writing/tags/ruby.atom | a tag on the page is renamed, polled with the time | UPDATE tags SET name = 'rails', updated_at = now() WHERE name = 'hanami'                                                                                  | the time              | /feed/entry/category/@term               | include        | rails                  |
      | /writing.atom           | the newest post loses a tag                  | DELETE FROM post_tags USING posts, tags WHERE post_tags.post_id = posts.id AND post_tags.tag_id = tags.id AND posts.slug = 'hello' AND tags.name = 'ruby' | the time | /feed/entry[category/@term='ruby']/id | is             | {site}/writing/older   |
      | /writing/tags/ruby.atom | the newest post loses a tag                  | DELETE FROM post_tags USING posts, tags WHERE post_tags.post_id = posts.id AND post_tags.tag_id = tags.id AND posts.slug = 'hello' AND tags.name = 'ruby' | the time | /feed/entry[category/@term='ruby']/id | is             | {site}/writing/older   |
      | /writing.atom           | a tag on the page is deleted                 | DELETE FROM tags WHERE name = 'hanami'                                                                                                      | the time              | /feed/entry/category/@term               | do not include | hanami                 |
      | /writing/tags/ruby.atom | a tag on the page is deleted                 | DELETE FROM tags WHERE name = 'hanami'                                                                                                      | the time              | /feed/entry/category/@term               | do not include | hanami                 |

  Scenario Outline: <path> still answers 304 to a poll with the time once <change>
    Given the posts:
      | title | tags         | published    | updated      | status |
      | Older | ruby         | 25 hours ago | 25 hours ago |        |
      | Hello | hanami, ruby | 1 day ago    | 1 day ago    |        |
      | Draft | ruby, secret |              |              | draft  |
    When I request "<path>"
    And I keep the feed's ETag and time
    And the database runs:
      """
      <statement>
      """
    And I poll "<path>" with the time
    Then it answers 304

    Examples:
      | path                    | change                             | statement                                                                                                                                     |
      | /writing.atom           | a post keeps its tags              | UPDATE post_tags SET tag_id = tag_id FROM posts WHERE post_id = posts.id AND slug = 'hello' |
      | /writing/tags/ruby.atom | a post keeps its tags              | UPDATE post_tags SET tag_id = tag_id FROM posts WHERE post_id = posts.id AND slug = 'hello' |
      | /writing.atom           | a draft loses a tag                | DELETE FROM post_tags USING posts, tags WHERE post_id = posts.id AND tag_id = tags.id AND slug = 'draft' AND tags.name = 'ruby'              |
      | /writing/tags/ruby.atom | a draft loses a tag                | DELETE FROM post_tags USING posts, tags WHERE post_id = posts.id AND tag_id = tags.id AND slug = 'draft' AND tags.name = 'ruby'              |
      | /writing.atom           | a tag off the page is renamed      | UPDATE tags SET name = 'hidden', updated_at = now() WHERE name = 'secret'                                                                                         |
      | /writing/tags/ruby.atom | a tag off the page is renamed      | UPDATE tags SET name = 'hidden', updated_at = now() WHERE name = 'secret'                                                                                         |

  Scenario Outline: <path> with an edit note answers 304 while nothing changes, and 200 with the revised note
    Given the posts:
      | title | tags         | published    | updated      |
      | Older | ruby         | 25 hours ago | 25 hours ago |
      | Hello | hanami, ruby | 1 day ago    | 1 day ago    |
    And the post "Older" carries the edit notes:
      | note         | at        |
      | fixed a typo | 1 day ago |
    When I request "<path>"
    And I keep the feed's ETag and time
    And I poll "<path>" with the ETag
    Then it answers 304
    When I poll "<path>" with the time
    Then it answers 304
    When the note "fixed a typo" is revised to "fixed two typos"
    And I poll "<path>" with the ETag
    Then it answers 200
    And the XML answer's "/feed/entry[title='Older']/content" matches "fixed two typos"
    When I poll "<path>" with the time
    Then it answers 200
    And the feed's ETag and time have both moved on
    And the XML answer's "/feed/entry[title='Older']/updated" is later than a day ago

    Examples:
      | path                    |
      | /writing.atom           |
      | /writing/tags/ruby.atom |

  Scenario Outline: The second page of <path> answers 304 while it stands, and 200 once a newer post pushes another onto it
    Given 26 published posts tagged "ruby"
    When I request "<path>?page=2"
    And I keep the feed's ETag and time
    And I poll "<path>?page=2" with the time
    Then it answers 304
    When I poll "<path>?page=2" with the ETag
    Then it answers 304
    Given the posts:
      | title  | tags | published |
      | Newest | ruby | now       |
    When I poll "<path>?page=2" with the ETag and the time
    Then it answers 200
    And the XML answer's "/feed/entry/id" are:
      | {site}/writing/post-25 |
      | {site}/writing/post-26 |

    Examples:
      | path                    |
      | /writing.atom           |
      | /writing/tags/ruby.atom |

  Scenario Outline: The second page of <path> answers 200 to a poll with the time once a newer post shifts it after its latest note
    Given 50 published posts tagged "ruby"
    And the post "Post 50" carries the edit notes:
      | note         | at          |
      | fixed a typo | 1 hour ago  |
    When I request "<path>?page=2"
    And I keep the feed's ETag and time
    Given the posts:
      | title  | tags | published |
      | Newest | ruby | now       |
    When I poll "<path>?page=2" with the time
    Then it answers 200
    And the XML answer's "/feed/entry[1]/id" is "{site}/writing/post-25"

    Examples:
      | path                    |
      | /writing.atom           |
      | /writing/tags/ruby.atom |

  Scenario: A later page of a tag feed answers 304 once a post under another tag is published
    Given 26 published posts tagged "ruby"
    When I request "/writing/tags/ruby.atom?page=2"
    And I keep the feed's ETag and time
    Given the posts:
      | title  | tags | published |
      | Newest | rust | now       |
    When I poll "/writing/tags/ruby.atom?page=2" with the time
    Then it answers 304

  Scenario: The last page answers 200 once an older post joins it
    Given 26 published posts
    When I request "/writing.atom?page=2"
    And I keep the feed's ETag and time
    Given the posts:
      | title  | published  |
      | Oldest | 3 days ago |
    When I poll "/writing.atom?page=2" with the ETag
    Then it answers 200

  Scenario Outline: <path> reads a time sent back in another shape
    Given the posts:
      | title | tags | published            | updated              |
      | Hello | ruby | 2026-10-01T12:00:00Z | 2026-10-01T12:00:00Z |
    When I request "<path>" with the header "If-Modified-Since" set to "Thu, 1 Oct 2026 12:00:00 GMT"
    Then it answers 304
    And the body is:
      """
      """
    When I request "<path>" with the header "If-Modified-Since" set to "Thu, 1 Oct 2026 11:59:59 GMT"
    Then it answers 200
    When I request "<path>" with the header "If-Modified-Since" set to "Thursday, 01-Oct-26 12:00:00 GMT"
    Then it answers 304
    When I request "<path>" with the header "If-Modified-Since" set to "not a date"
    Then it answers 200
    And the XML answer passes the schema "atom.rng"

    Examples:
      | path                    |
      | /writing.atom           |
      | /writing/tags/ruby.atom |

  Scenario: A request arriving on another host names the site setting in the feeds and entry ids, as the canonical link does
    Given the posts:
      | title | tags |
      | Hello | ruby |
    And my requests send the header "Host" as "pi.local"
    When I request "/writing.atom"
    Then the XML answer's "/feed/entry/id" are:
      | {site}/writing/hello |
    And the XML answer's "/feed/link[@rel='alternate']/@href" is "{site}/writing"
    And the XML answer's "/feed/link[@rel='self']/@href" is "{site}/writing.atom"
    When I request "/writing/tags/ruby.atom"
    Then the XML answer's "/feed/link[@rel='self']/@href" is "{site}/writing/tags/ruby.atom"
    When I request "/writing/hello"
    Then the body includes "<link rel=\"canonical\" href=\"{site}/writing/hello\">"
