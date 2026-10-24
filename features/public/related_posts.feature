Feature: Related posts
  Under a post, up to three published posts that share its tags, most shared first then newest, filled out with
  posts in similar wording. A record link between posts does not count.

  Scenario: The related block sits after the post extras and before the pager
    Given the posts:
      | title | tags | published      |
      | Hello | ruby | 1 minute ago   |
      | Other | ruby | 2 minutes ago  |
    When I visit "/writing/hello"
    Then the page has "article.post > .post-extras + section.rel + nav.pgr"
    And the page has no axe breaches in light or dark

  Scenario: The related block shows at most three posts
    Given the posts:
      | title   | tags | published     |
      | Hello   | ruby | 1 minute ago  |
      | Other-2 | ruby | 2 minutes ago |
      | Other-3 | ruby | 3 minutes ago |
      | Other-4 | ruby | 4 minutes ago |
      | Other-5 | ruby | 5 minutes ago |
      | Other-6 | ruby | 6 minutes ago |
    When I visit "/writing/hello"
    Then the texts of ".rel li .rt" are:
      | Other-2 |
      | Other-3 |
      | Other-4 |

  Scenario: Posts sharing more tags rank first, then the newest
    Given the posts:
      | title   | tags              | published     |
      | Hello   | ruby, hanami, rom | 1 minute ago  |
      | One-new | ruby              | 2 minutes ago |
      | Two     | ruby, hanami      | 3 minutes ago |
      | One-old | rom               | 4 minutes ago |
    When I visit "/writing/hello"
    Then the texts of ".rel li .rt" are:
      | Two     |
      | One-new |
      | One-old |

  Scenario: A card names the tags it shares, links to its post and shows its summary
    Given the posts:
      | title | tags         | published     | summary         |
      | Hello | ruby, hanami | 1 minute ago  |                 |
      | Other | hanami, rust | 2 minutes ago | a short summary |
    When I visit "/writing/hello"
    Then the page has ".rel li .rm time"
    And ".rel li .rm" includes "shares"
    And the links in ".rel .rm a.post-tag" go to:
      | /writing/tags/hanami |
    And the texts of ".rel .rm a.post-tag" are:
      | hanami |
    And ".rel a.rt[href='/writing/other']" reads "Other"
    And ".rel p.rs" reads "a short summary"

  Scenario: Posts in similar wording fill the empty slots, each labelled with why it is related
    Given the posts:
      | title     | tags | published     | body                                  |
      | Hello     | ruby | 1 minute ago  | providers wire the container together |
      | Tagged    | ruby | 2 minutes ago | plain words                           |
      | Worded    |      | 3 minutes ago | a container holds providers           |
      | Unrelated |      | 4 minutes ago | cats sleep all afternoon              |
    When I visit "/writing/hello"
    Then the texts of ".rel li .rt" are:
      | Tagged |
      | Worded |
    And the texts of ".rel li .rm span" are:
      | shares ruby     |
      | similar wording |

  Scenario: The closer wording ranks first
    Given the posts:
      | title | published     | body                                  |
      | Hello | 1 minute ago  | providers wire the container together |
      | Near  | 3 minutes ago | providers wire a container            |
      | Far   | 2 minutes ago | a container                           |
    When I visit "/writing/hello"
    Then the texts of ".rel li .rt" are:
      | Near |
      | Far  |

  Scenario: Drafts, scheduled posts and the post itself never show
    Given the posts:
      | title | tags | status    | published     | body                         |
      | Hello | ruby |           | 1 minute ago  | providers wire the container |
      | Draft | ruby | draft     |               | providers wire the container |
      | Later | ruby | scheduled | in 1 day      | providers wire the container |
    When I visit "/writing/hello"
    Then the page has no ".rel"

  Scenario: The block hides when no post qualifies
    Given the posts:
      | title | tags | published     | body                         |
      | Hello | ruby | 1 minute ago  | providers wire the container |
      | Other | rust | 2 minutes ago | cats sleep all afternoon     |
    When I visit "/writing/hello"
    Then the page has no ".rel"

  Scenario: A record link between posts does not make them related
    Given the posts:
      | title | published     | body                         |
      | Hello | 1 minute ago  | providers wire the container |
      | Other | 2 minutes ago | cats sleep all afternoon     |
    And the post "Hello" links to the post "Other"
    When I visit "/writing/hello"
    Then the page has no ".rel"
