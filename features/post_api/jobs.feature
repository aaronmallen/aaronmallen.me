Feature: Blog post jobs
  Scheduled posts publish once due and then send their webmentions, stored renderings rebuild from the Markdown,
  and the follow-ups of a publish wait in the database while the job queue is down.

  Scenario: The due posts job publishes each due post at its set time and leaves the rest alone
    Given the posts table holds:
      | title  | status    | published_at         | updated_at           |
      | One    | scheduled | 2026-10-01T10:00:00Z | 2026-10-01T09:00:00Z |
      | Two    | scheduled | 2026-10-02T10:00:00Z | 2026-10-01T09:00:00Z |
      | Later  | scheduled | in 1 hour            | 2026-10-01T09:00:00Z |
      | Draft  | draft     | null                 | 2026-10-01T09:00:00Z |
      | Live   | published | 2026-09-01T10:00:00Z | 2026-10-01T09:00:00Z |
    When the job "Posts::Jobs::PublishDuePosts" runs
    Then the posts table has a row with:
      | title | status    | published_at             |
      | One   | published | 2026-10-01T10:00:00.000Z |
    And the posts table has a row with:
      | title | status    | published_at             |
      | Two   | published | 2026-10-02T10:00:00.000Z |
    And the posts table has a row with:
      | title | status    |
      | Later | scheduled |
    And the posts table has a row with:
      | title | status |
      | Draft | draft  |
    And the posts table has a row with:
      | title | status    | updated_at               |
      | Live  | published | 2026-10-01T09:00:00.000Z |

  Scenario: A post the due posts job publishes sends its webmentions
    Given the posts table holds:
      | title | status    | published_at         | body                                    |
      | One   | scheduled | 2026-10-01T10:00:00Z | See [a note](http://203.0.113.50/page). |
    And the web answers GET "http://203.0.113.50/page" with:
      """
      <p>a note with no endpoint</p>
      """
    When the job "Posts::Jobs::PublishDuePosts" runs
    Then the posts table has a row with:
      | title | status    | webmention_targets         |
      | One   | published | {http://203.0.113.50/page} |

  Scenario: The rerender job rebuilds each stored value from the Markdown and leaves updated_at alone
    Given the posts table holds:
      | title | body                         | body_html  | first_paragraph | read_time | word_count | updated_at           |
      | Hello | ## Setup\n\none *two* three  | <p>old</p> | old             | 9         | 1          | 2026-10-01T09:00:00Z |
    And the post_edits table holds:
      | post_id | note       | note_html  |
      | 1       | Fixed *it* | <p>old</p> |
    When the job "Posts::Jobs::RerenderPosts" runs
    Then the posts table has a row with:
      | first_paragraph | read_time | word_count | updated_at               |
      | one two three   | 1         | 4          | 2026-10-01T09:00:00.000Z |
    And blog post 1's rendered body holds "<em>two</em>"
    And edit note 1's rendered note reads "<p>Fixed <em>it</em></p>\n"

  Scenario: Publishing while the job queue is down holds the follow-ups and sends them once it is back
    Given I am signed in to the admin
    And a Mastodon account on "203.0.113.60" takes announcements
    And the web answers GET "http://203.0.113.51/note" with:
      """
      <html><head><link rel="webmention" href="http://203.0.113.51/webmention"></head><body>a</body></html>
      """
    And the web answers POST "http://203.0.113.51/webmention" with status 202
    When I visit "/admin/posts/new"
    And Redis goes down
    And I send the post editor form to "/admin/posts" with:
      | intent      | publish                                 |
      | post[title] | Hello                                  |
      | post[slug]  | hello                                  |
      | post[body]  | See [a note](http://203.0.113.51/note). |
      | post[syndication_enabled]       | 1               |
      | post[syndication_body]          | In my own words |
      | post[syndication_targets][]     | mastodon        |
    Then that answers 302
    And the posts table has a row with:
      | title | status    |
      | Hello | published |
    And the held_post_follow_ups table has a row with:
      | post_id | follow_up        |
      | 1       | send_webmentions |
    And the held_post_follow_ups table has a row with:
      | post_id | follow_up      |
      | 1       | syndicate_post |
    Given jobs left over from before have finished
    When Redis comes back
    And the job "Posts::Jobs::QueueHeldFollowUps" runs and finishes
    And the job "Posts::Jobs::QueueHeldFollowUps" runs and finishes
    Then the held_post_follow_ups table holds 0 rows
    And the job "Social::Jobs::SyndicatePost" has run 1 time and no more
    And the job "Social::Jobs::SendWebmentions" has run 1 time and no more
    And the web heard POST "http://203.0.113.51/webmention" 1 time
    And the social_posts table has a row with:
      | post_id | targets    |
      | 1       | {mastodon} |
    And the posts table has a row with:
      | title | webmention_targets         | unsent_webmention_targets |
      | Hello | {http://203.0.113.51/note} | {}                        |

  Scenario: Saving a published post while the job queue is down holds its webmentions until it is back
    Given I am signed in to the admin
    And the posts table holds:
      | title | slug  | status    | published_at | body                                    |
      | Hello | hello | published | 1 day ago    | See [a note](http://203.0.113.51/note). |
    And the web answers GET "http://203.0.113.51/note" with:
      """
      <html><head><link rel="webmention" href="http://203.0.113.51/webmention"></head><body>a</body></html>
      """
    And the web answers POST "http://203.0.113.51/webmention" with status 202
    When I visit "/admin/posts/1/edit"
    And Redis goes down
    And I send the post editor form to "/admin/posts/1" with:
      | intent      | save                                    |
      | post[title] | Changed                                 |
      | post[slug]  | hello                                   |
      | post[body]  | See [a note](http://203.0.113.51/note). |
    Then that answers 302
    And the posts table has a row with:
      | title   |
      | Changed |
    And the held_post_follow_ups table holds 1 rows
    When Redis comes back
    And the job "Posts::Jobs::QueueHeldFollowUps" runs
    Then the held_post_follow_ups table holds 0 rows
    And the posts table has a row with:
      | title   | webmention_targets         |
      | Changed | {http://203.0.113.51/note} |

  Scenario: The held follow-ups job queues nothing when nothing is held
    Given jobs left over from before have finished
    When the job "Posts::Jobs::QueueHeldFollowUps" runs and finishes
    Then the job "Social::Jobs::SyndicatePost" has run 0 times and no more
    And the job "Social::Jobs::SendWebmentions" has run 0 times and no more

  Scenario: Running the due posts job twice publishes a post and sends its follow-ups once
    Given a Mastodon account on "203.0.113.60" takes announcements
    And the posts table holds:
      | title | status    | published_at         | body                                    | syndication_enabled | syndication_body | syndication_targets |
      | One   | scheduled | 2026-10-01T10:00:00Z | See [a note](http://203.0.113.50/page). | true                | Out now          | {mastodon}          |
    And the web answers GET "http://203.0.113.50/page" with:
      """
      <p>a note with no endpoint</p>
      """
    Given jobs left over from before have finished
    When the job "Posts::Jobs::PublishDuePosts" runs and finishes
    And the job "Posts::Jobs::PublishDuePosts" runs and finishes
    Then the posts table has a row with:
      | title | status    | published_at             |
      | One   | published | 2026-10-01T10:00:00.000Z |
    And the job "Social::Jobs::SyndicatePost" has run 1 time and no more
    And the job "Social::Jobs::SendWebmentions" has run 1 time and no more
    And the social_posts table holds 1 rows
