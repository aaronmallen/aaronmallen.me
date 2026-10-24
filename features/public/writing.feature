Feature: Writing
  The writing index lists published posts newest first, 25 to a page, each with a blurb and a meta column. An
  article renders its body with heading ids, a table of contents, sized media and a pager to its neighbours.

  Scenario: The writing index renders with no posts
    When I visit "/writing"
    Then "main > section .kicker" includes "Writing"
    And the page has ".writing-empty"
    And the page has no axe breaches in light or dark

  Scenario: The writing index lists only published posts, newest first, each title linked to its article
    Given the posts:
      | title | status    | published     |
      | Older |           | 2 minutes ago |
      | Newer |           | 1 minute ago  |
      | Draft | draft     |               |
      | Later | scheduled | in 1 day      |
    When I visit "/writing"
    Then the texts of ".entry .entry-title" are:
      | Newer |
      | Older |
    And ".entry-title a.entry-link[href='/writing/newer']" reads "Newer"

  Scenario Outline: The blurb is <what>
    Given the posts:
      | title | summary   | body   |
      | Hello | <summary> | <body> |
    When I visit "/writing"
    Then ".entry-blurb" reads "<blurb>"

    Examples:
      | what                                                    | summary          | body                                    | blurb                     |
      | the summary the post carries                            | What it is about | ## Intro\n\nthe first part              | What it is about          |
      | the first paragraph when nobody wrote a summary         |                  | ## Intro\n\nthe first part\n\nthe second part | the first part      |
      | a hand-written summary cut at the budget                | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa bbbb | the first part | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa… |
      | a first paragraph cut at the budget with an ellipsis    |                  | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa bbbb | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa… |
      | cut with a family emoji kept whole                      |                  | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa👩‍👩‍👧‍👦 x | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa👩‍👩‍👧‍👦… |

  Scenario: The blurb is left out when the body has no paragraph
    Given the posts:
      | title | body             |
      | Hello | ## Only a heading |
    When I visit "/writing"
    Then ".entry-title" includes "Hello"
    And the page has no ".entry-blurb"

  Scenario: The meta column holds the date, the tags linked in their colour and the read time
    Given the database runs:
      """
      INSERT INTO tags (name, color, scope) VALUES ('ruby', 'mk-violet', 'public')
      """
    And the posts:
      | title | tags | published            | body                                                 |
      | Hello | ruby | 2026-09-07T12:00:00Z | [<440 words>](https://example.test/a/very/long/url) |
    When I visit "/writing"
    Then the texts of ".entry-meta > *" are:
      | Sep 7, 2026 |
      | ruby        |
      | 2 min       |
    And ".entry-meta a.post-tag.violet[href='/writing/tags/ruby']" reads "ruby"

  Scenario: The writing index is titled, headed with a heading it never draws over the kicker, and links the feed once
    When I visit "/writing"
    Then the page title is "Writing | Aaron Allen"
    And "main > section > h1.sr-only:first-child" reads "Writing"
    And "main > section > .kicker" reads "Writing · newest first"
    And the page has 1 of "h1"
    And the page has no "main > section p.eyebrow"
    And the page has 1 of "head link[rel='alternate'][type='application/atom+xml']"
    And the page has "head link[rel='alternate'][type='application/atom+xml'][href='/writing.atom'][title='Writing | Aaron Allen']"

  Scenario: Paging shows the newest 25 and links to older posts, and the next page links both ways
    Given 55 published posts
    When I visit "/writing"
    Then the first of ".entry .entry-title" reads "Post 1" and the last "Post 25", 25 in all
    And "nav.pager a[rel='next'][href='/writing?page=2']" reads "Older"
    And the page has no "nav.pager a[rel='prev']"
    When I visit "/writing?page=2"
    Then the first of ".entry .entry-title" reads "Post 26" and the last "Post 50", 25 in all
    And "nav.pager a[rel='prev'][href='/writing']" reads "Newer"
    And "nav.pager a[rel='next'][href='/writing?page=3']" reads "Older"
    And "main > section > h1.sr-only" reads "Writing"
    And "link[rel='canonical']" has the attribute "href" set to "{site}/writing?page=2"

  Scenario: The last page links only to newer posts
    Given 55 published posts
    When I visit "/writing?page=3"
    Then the first of ".entry .entry-title" reads "Post 51" and the last "Post 55", 5 in all
    And the page has "nav.pager a[rel='prev'][href='/writing?page=2']"
    And the page has no "nav.pager a[rel='next']"

  Scenario: No pager draws when one page holds every post
    Given 25 published posts
    When I visit "/writing"
    Then the page has no "nav.pager"

  Scenario Outline: The page <page> is no page and answers 404
    Given 55 published posts
    When I request "/writing?page=<page>"
    Then it answers 404

    Examples:
      | page       |
      | 4          |
      | 0          |
      | -1         |
      | 1.5        |
      | two        |
      |            |
      | 2147483648 |

  Scenario: A page given as a list answers 404
    When I request "/writing?page[]=2"
    Then it answers 404

  Scenario: An article renders a published post under its back link and title
    Given the posts:
      | title | body                              |
      | Hello | the start\n\n## More\n\nthe rest  |
    When I visit "/writing/hello"
    Then "article.post a.post-back[href='/writing'] + header h1.post-title" reads "Hello"
    And ".prose > p:first-child" reads "the start"
    And the page has ".prose h2"
    And the page has ".e-content + .endmark[aria-hidden='true'] > .glasses"
    And the page title is "Hello | Aaron Allen"
    And the page has no axe breaches in light or dark

  Scenario: Every heading gets an id from its text, repeats numbered, with no empty link inside
    Given the posts:
      | title | body                                                   |
      | Hello | ## Setup\n\n### The `config` file\n\n## Setup          |
    When I visit "/writing/hello"
    Then the ids of ".prose h2, .prose h3" are:
      | setup           |
      | the-config-file |
      | setup-1         |
    And the page has no ".prose h2 a, .prose h3 a"

  Scenario: A level one heading in the body becomes an h2, keeping one h1
    Given the posts:
      | title | body                 |
      | Hello | # Big\n\nthe rest    |
    When I visit "/writing/hello"
    Then the page has 1 of "h1"
    And ".prose h2#big" reads "Big"

  Scenario: Three or more h2s are listed beside the body, each pointing at its h2
    Given the posts:
      | title | body                                                   |
      | Hello | ## One\n\n### Under\n\n## Two *more*\n\n## One         |
    When I visit "/writing/hello"
    Then ".post-g > aside.toc[aria-label='On this page'] > h2" reads "On this page"
    And the hrefs and texts of ".toc li a" are:
      | #one      | One      |
      | #two-more | Two more |
      | #one-1    | One      |
    And the ids of ".prose h2" are:
      | one      |
      | two-more |
      | one-1    |

  Scenario: Fewer than three h2s list nothing beside the body
    Given the posts:
      | title | body                                              |
      | Hello | ## One\n\n### Under\n\n#### Deep\n\n## Two        |
    When I visit "/writing/hello"
    Then the page has no ".toc"

  Scenario: Remote images stay, and every image after the first loads lazily
    Given the posts:
      | title | body                                                                                                                    |
      | Hello | ![one](https://example.com/1.png)\n\n![two](https://example.com/2.png)\n\n![three](https://example.com/3.png "Caption") |
    And the web answers images blank
    When I visit "/writing/hello"
    Then the page has ".prose img[src='https://example.com/1.png'][alt='one']:not([loading]):not([decoding])"
    And the page has ".prose p img[src$='2.png'][loading='lazy'][decoding='async']"
    And the page has ".prose figure.fig img[src$='3.png'][loading='lazy'][decoding='async']"

  Scenario: An image from the site's media gets the photo's size, sized widths too, with no srcset when it has no smaller widths
    Given the photos:
      | key                                  | width | height |
      | 00000000000000000000000000000001.jpg | 1200  | 800    |
    And the posts:
      | title | body                                                                                                          |
      | Hello | ![shot](/media/00000000000000000000000000000001.jpg)\n\n![shot](/media/1280/00000000000000000000000000000001.jpg) |
    When I visit "/writing/hello"
    Then the page has ".prose img[src='/media/00000000000000000000000000000001.jpg'][width='1200'][height='800']"
    And the page has ".prose img[src='/media/1280/00000000000000000000000000000001.jpg'][width='1200'][height='800']"
    And the page has no ".prose img[srcset], .prose img[sizes]"

  Scenario: A site media image with smaller widths lists each in its srcset, sized to the post column
    Given the photos:
      | key                                  | width | height | widths   |
      | 00000000000000000000000000000002.jpg | 1500  | 1000   | 640,1280 |
    And the posts:
      | title | body                                                 |
      | Hello | ![shot](/media/00000000000000000000000000000002.jpg) |
    When I visit "/writing/hello"
    Then ".prose img" has the attribute "srcset" set to "/media/640/00000000000000000000000000000002.jpg 640w, /media/1280/00000000000000000000000000000002.jpg 1280w, /media/00000000000000000000000000000002.jpg 1500w"
    And ".prose img" has the attribute "sizes" set to "(min-width: 44em) 44em, 100vw"

  Scenario: A site media image with no known size renders without one
    Given the posts:
      | title | body                                                 |
      | Hello | ![shot](/media/ffffffffffffffffffffffffffffffff.png) |
    When I visit "/writing/hello"
    Then the page has ".prose img[src='/media/ffffffffffffffffffffffffffffffff.png']"
    And the page has no ".prose img[width], .prose img[height]"

  Scenario: A titled image alone in its paragraph draws as a captioned figure
    Given the posts:
      | title | body                                                                   |
      | Hello | the start\n\n![shot](https://example.com/shot.png "Fish & <chips>")     |
    And the web answers images blank
    When I visit "/writing/hello"
    Then the page has ".prose > figure.fig > img[src='https://example.com/shot.png'][alt='shot']"
    And "figure.fig > img + figcaption" reads "Fish & <chips>"
    And the page has no "figure.fig img[title]"

  Scenario Outline: <what> stays in its paragraph
    Given the posts:
      | title | body                 |
      | Hello | the start\n\n<image> |
    And the web answers images blank
    When I visit "/writing/hello"
    Then the page has ".prose > p img[src='https://example.com/shot.png']"
    And the page has no "figure"

    Examples:
      | what                                 | image                                                                  |
      | An untitled image                    | ![shot](https://example.com/shot.png)                                  |
      | A titled image sharing its paragraph | see ![shot](https://example.com/shot.png "Caption")                    |
      | A linked titled image                | [![shot](https://example.com/shot.png "Caption")](https://example.com) |

  Scenario: The article closes with a feedback line linking to contact
    Given the posts:
      | title |
      | Hello |
    When I visit "/writing/hello"
    Then "article.post .post-extras > p.post-feedback" reads "Found a typo or want to argue about patterns? Let me know."
    And "article.post .post-extras > p.post-feedback" has a link "Let me know" to "/contact"

  Scenario: The meta row shows the date, the tags linked to their pages and the read time, and the head links the feed
    Given the posts:
      | title | tags         | published            |
      | Hello | ruby, hanami | 2026-09-07T12:00:00Z |
    When I visit "/writing/hello"
    Then "header .post-meta time" reads "Sep 7, 2026"
    And the links in "header .post-meta a.post-tag" go to:
      | /writing/tags/hanami |
      | /writing/tags/ruby   |
    And the page has "header .post-meta span:text-is('1 min')"
    And the page has "head link[rel='alternate'][type='application/atom+xml'][href='/writing.atom'][title='Writing | Aaron Allen']"
    And the page has 1 of "head link[rel='alternate'][type='application/atom+xml']"

  Scenario: The pager links the previous post, all writing and the next post in publish order
    Given the posts:
      | title  | published     |
      | First  | 3 minutes ago |
      | Second | 2 minutes ago |
      | Third  | 1 minute ago  |
    When I visit "/writing/second"
    Then the links in "nav.pgr a.card" go to:
      | /writing/first |
      | /writing       |
      | /writing/third |
    And "nav.pgr a.card[rel='prev'] .t" reads "First"
    And "nav.pgr a.card.nx[rel='next'] .t" reads "Third"
    And "nav.pgr[aria-label='More posts'] a.card.all[href='/writing']" includes "All writing"
    And "nav.pgr a.all .t" reads "Everything, newest first"
    And the page has no "footer.post-footer"

  Scenario: The oldest post has no previous and the newest no next
    Given the posts:
      | title  | published     |
      | First  | 2 minutes ago |
      | Second | 1 minute ago  |
    When I visit "/writing/first"
    Then the page has no "a[rel='prev']"
    And the page has "a[rel='next'][href='/writing/second']"
    When I visit "/writing/second"
    Then the page has no "a[rel='next']"
    And the page has "a[rel='prev'][href='/writing/first']"

  Scenario: The pager skips drafts and scheduled posts
    Given the posts:
      | title | status    | published |
      | Only  |           |           |
      | Draft | draft     |           |
      | Later | scheduled | in 1 day  |
    When I visit "/writing/only"
    Then the links in "nav.pgr a.card" go to:
      | /writing |

  Scenario Outline: A <status> post answers 404
    Given the posts:
      | title  | status   | published   |
      | Hidden | <status> | <published> |
    When I request "/writing/hidden"
    Then it answers 404

    Examples:
      | status    | published |
      | draft     |           |
      | scheduled | in 1 day  |

  Scenario Outline: The slug <slug> answers 404
    Given the posts:
      | title |
      | Hello |
    When I request "/writing/<slug>"
    Then it answers 404

    Examples:
      | slug        |
      | nothing     |
      | Hello       |
      | -hello      |
      | hello-      |
      | hello--world |
      | h%C3%A9llo  |
      | hello_world |
      | tags        |

  Scenario: A slug no post has gets the site's not found page
    When I request "/writing/nothing"
    Then the "Content-Type" header starts with "text/html"
    And the body is the file "public/404.html"

  Scenario: The blurb joins a wrapped first paragraph with a space, and is left out for a lone image with no alt text
    Given the posts:
      | title   | body                                                  | published     |
      | Wrapped | the first line\nwraps onto the next                   | 1 minute ago  |
      | Imaged  | ![](https://example.com/a.png)\n\nthe second part     | 2 minutes ago |
    When I visit "/writing"
    Then ".entry:has(a[href='/writing/wrapped']) .entry-blurb" reads "the first line wraps onto the next"
    And the page has no ".entry:has(a[href='/writing/imaged']) .entry-blurb"

  Scenario: The post page and the writing page show the stored rendering, not the Markdown
    Given the posts:
      | title | body         |
      | Hello | the markdown |
    And the database runs:
      """
      UPDATE posts SET body_html = '<p>stored html</p>', first_paragraph = 'stored blurb', read_time = 7
      """
    When I visit "/writing/hello"
    Then ".prose p" reads "stored html"
    And the page does not show "the markdown"
    And ".post-meta" includes "7 min"
    When I visit "/writing"
    Then ".entry-blurb" reads "stored blurb"

  Scenario: Two posts published at the same time page by id, the older as previous
    Given two posts "First" and "Second" published at the same moment
    When I visit "/writing/second"
    Then the page has "nav.pgr a[rel='prev'][href='/writing/first']"
    And the page has no "nav.pgr a[rel='next']"
    When I visit "/writing/first"
    Then the page has "nav.pgr a[rel='next'][href='/writing/second']"
    And the page has no "nav.pgr a[rel='prev']"
