@timeout:180_000
Feature: Media
  /media serves the photos a published post, or a task or comment on a published board, shows, streamed from the
  media store and cached for a year. Any other photo is the owner's alone, and a bad key, a missing key or a
  store that cannot be reached gets an empty 404 cached for a minute.

  Background:
    Given the media store is the stub
    And the site runs in development
    And the photos:
      | key                                  | width | height | widths   |
      | a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg | 1500  | 1000   | 640,1280 |

  Scenario: A photo a published post shows comes back with its bytes, type, length, tag and a year's cache
    Given the posts:
      | title |
      | Shown |
    And the photo "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg" is claimed by:
      | owner | record |
      | post  | Shown  |
    And the store holds "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg" as "photo"
    When I request "/media/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then it answers 200
    And the body is:
      """
      photo
      """
    And the "Content-Type" header is "image/jpeg"
    And the "Content-Length" header is "5"
    And the "Cache-Control" header is "public, max-age=31536000, s-maxage=86400, immutable"
    And there is no "Vary" header
    And the "ETag" header is "\"a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg\""
    Given my requests send the header "Accept" as "image/avif,image/webp"
    When I request "/media/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then it answers 200

  Scenario: A HEAD answers the headers with no bytes, and a draft beside the post keeps the photo public
    Given the posts:
      | title | status |
      | Shown |        |
      | Draft | draft  |
    And the photo "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg" is claimed by:
      | owner | record |
      | post  | Shown  |
      | post  | Draft  |
    And the store answers only a HEAD for "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg" as "photo"
    When I send a HEAD to "/media/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then it answers 200
    And the body is:
      """
      """
    And the "Content-Type" header is "image/jpeg"
    And the "Cache-Control" header is "public, max-age=31536000, s-maxage=86400, immutable"

  Scenario: A browser that holds the photo gets an empty 304 with its tag and cache, never asking the store
    Given the posts:
      | title |
      | Shown |
    And the photo "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg" is claimed by:
      | owner | record |
      | post  | Shown  |
    And my requests send the header "If-None-Match" as "\"a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg\""
    When I request "/media/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then it answers 304
    And the body is:
      """
      """
    And the "ETag" header is "\"a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg\""
    And the "Cache-Control" header is "public, max-age=31536000, s-maxage=86400, immutable"
    Given my requests send the header "If-None-Match" as "\"other\", W/\"a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg\""
    When I request "/media/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then it answers 304

  Scenario: A browser that holds another photo gets this one
    Given the posts:
      | title |
      | Shown |
    And the photo "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg" is claimed by:
      | owner | record |
      | post  | Shown  |
    And the store holds "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg" as "photo"
    And my requests send the header "If-None-Match" as "\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg\""
    When I request "/media/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then it answers 200
    And the body is:
      """
      photo
      """

  Scenario Outline: A photo <owner> shows comes back to a visitor with the published cache
    Given the projects:
      | name  | board     |
      | Board | published |
    And the tasks of the project "Board":
      | title    |
      | On board |
    And the database runs:
      """
      INSERT INTO task_comments (task_id, body) SELECT id, 'a comment' FROM tasks WHERE title = 'On board'
      """
    And the photo "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg" is claimed by:
      | owner   | record   |
      | <claim> | On board |
    And the store holds "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg" as "photo"
    When I request "/media/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then it answers 200
    And the "Cache-Control" header is "public, max-age=31536000, s-maxage=86400, immutable"

    Examples:
      | owner                                    | claim        |
      | a task on a published board              | task         |
      | a comment on a task on a published board | task_comment |

  Scenario Outline: A photo no published post shows, when <owner>, is a visitor's empty 404 cached a minute, never asking the store
    Given the photo setup "<owner>"
    When I request "/media/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then it answers 404
    And the body is:
      """
      """
    And the "Cache-Control" header is "public, max-age=60"
    And there is no "Vary" header
    Given my requests send the header "If-None-Match" as "\"a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg\""
    When I request "/media/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then it answers 404
    And there is no "ETag" header

    Examples:
      | owner                                            |
      | no record claims it                              |
      | a draft post claims it                           |
      | a scheduled post claims it                       |
      | a journal entry claims it                        |
      | a task that is gone claims it                    |
      | a task on an unpublished board claims it         |
      | a task on a private project's board claims it    |
      | a task on no project claims it                   |
      | a comment on a task off a published board claims it |

  Scenario: A photo turns private again once its post is unpublished
    Given the posts:
      | title |
      | Shown |
    And the photo "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg" is claimed by:
      | owner | record |
      | post  | Shown  |
    And the database runs:
      """
      UPDATE posts SET status = 'draft'
      """
    When I request "/media/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then it answers 404

  Scenario: A stored width of a published photo serves like the photo, under its own tag
    Given the posts:
      | title |
      | Shown |
    And the photo "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg" is claimed by:
      | owner | record |
      | post  | Shown  |
    And the store holds "640/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg" as "small"
    When I request "/media/640/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then the body is:
      """
      small
      """
    And the "Content-Type" header is "image/jpeg"
    And the "Cache-Control" header is "public, max-age=31536000, s-maxage=86400, immutable"
    And the "ETag" header is "\"640/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg\""
    Given my requests send the header "If-None-Match" as "\"a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg\""
    When I request "/media/640/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then the body is:
      """
      small
      """

  Scenario: A browser that holds a width gets a 304 that never asks the store
    Given the posts:
      | title |
      | Shown |
    And the photo "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg" is claimed by:
      | owner | record |
      | post  | Shown  |
    And my requests send the header "If-None-Match" as "\"640/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg\""
    When I request "/media/640/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then it answers 304

  Scenario: A width the photo does not store answers 404, never asking the store
    Given the posts:
      | title |
      | Shown |
    And the photo "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg" is claimed by:
      | owner | record |
      | post  | Shown  |
    When I request "/media/960/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then it answers 404

  Scenario: A width of a photo no published post shows answers 404, never asking the store
    Given the photo setup "a draft post claims it"
    When I request "/media/640/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then it answers 404

  Scenario: An unknown key answers an empty 404 with no tag, cached a minute and not keyed on the cookie
    Given the store has no "ffffffffffffffffffffffffffffffff.jpg"
    When I request "/media/ffffffffffffffffffffffffffffffff.jpg"
    Then it answers 404
    And the body is:
      """
      """
    And there is no "ETag" header
    And the "Cache-Control" header is "public, max-age=60"
    And there is no "Vary" header

  Scenario Outline: The key <key>, which is no photo key, answers an empty 404 cached a minute, never asking the store
    When I request "/media/<key>"
    Then it answers 404
    And the body is:
      """
      """
    And the "Cache-Control" header is "public, max-age=60"

    Examples:
      | key                                      |
      | a1b2c3.jpg                               |
      | A1B2C3D4A1B2C3D4A1B2C3D4A1B2C3D4.jpg     |
      | a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.svg     |
      | a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg.png |
      | ..%2Fsecret.jpg                          |

  Scenario: A store that cannot be reached answers the photo with an empty 404, and the post still loads
    Given the posts:
      | title | body                                                    |
      | Shown | ![A photo](/media/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg) |
    And the photo "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg" is claimed by:
      | owner | record |
      | post  | Shown  |
    And the store cannot be reached for "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    When I request "/media/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then it answers 404
    And the body is:
      """
      """
    And the "Cache-Control" header is "public, max-age=60"
    And there is no "ETag" header
    When I request "/writing/shown"
    Then it answers 200
    And the body includes "src=\"/media/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg\""

  Scenario: A store with no settings answers an empty 404
    Given the environment sets MEDIA_STORE_ACCESS_KEY to ""
    And the site runs in development
    And the posts:
      | title |
      | Shown |
    And the photo "a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg" is claimed by:
      | owner | record |
      | post  | Shown  |
    When I request "/media/a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4.jpg"
    Then it answers 404
    And the body is:
      """
      """
