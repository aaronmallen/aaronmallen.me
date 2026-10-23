Feature: Every admin page passes axe
  Each admin page that answers HTML passes the axe checks in light and dark on development seeds. The JSON
  answers, redirects, the event stream, the mail attachment and the people search fragment are no pages, and each
  menu is a fragment its page loads into a context menu. The test server cannot read the service credentials the
  development seeds seal under their own key, so the scenario drops them first.

  @timeout:900_000
  Scenario: Every admin page answers and passes axe in light and dark
    Given I seed the database as development
    And the database runs "DELETE FROM service_connections"
    And I am signed in to the admin
    And the project "AXE"
    And the table tags holds:
      | name      | color   | scope   | project_id                                  |
      | axe-check | mk-pink | project | (SELECT id FROM projects WHERE key = 'AXE') |
    And the table pull_requests holds:
      | repo             | number | title             | url                                           | opened_at  |
      | aaronmallen/blog | 7      | Add the importer  | https://github.com/aaronmallen/blog/pull/7    | 1 hour ago |
    Then every admin GET route in slices/admin/config/routes.rb is a page below or left out for a reason:
      | route                                    | page                               | left out because                                                         |
      | /                                        | /                                  |                                                                          |
      | /activity                                | /activity                          |                                                                          |
      | /agents/artifacts                        | /agents/artifacts                  |                                                                          |
      | /agents/artifacts/new                    | /agents/artifacts/new              |                                                                          |
      | /agents/artifacts/:id                    | /agents/artifacts/{artifacts}      |                                                                          |
      | /agents/artifacts/:id/edit               | /agents/artifacts/{artifacts}/edit |                                                                          |
      | /agents/memories                         | /agents/memories                   |                                                                          |
      | /agents/memories/:id                     | /agents/memories/{memory_files}    |                                                                          |
      | /agents/sessions                         | /agents/sessions                   |                                                                          |
      | /analytics                               | /analytics                         |                                                                          |
      | /attention/menu                          |                                    | a menu fragment its page loads into a context menu                       |
      | /calendar                                | /calendar                          |                                                                          |
      | /calendar/events/:id/menu                |                                    | a menu fragment its page loads into a context menu                       |
      | /clients/:id/menu                        |                                    | a menu fragment its page loads into a context menu                       |
      | /commits/:id                             | /commits/{commits}                 |                                                                          |
      | /commits/:id/menu                        |                                    | a menu fragment its page loads into a context menu                       |
      | /contacts                                | /contacts                          |                                                                          |
      | /contacts/new                            | /contacts/new                      |                                                                          |
      | /contacts/search/:network                |                                    | a results fragment the person search screen shows                        |
      | /contacts/:id                            | /contacts/{people}                 |                                                                          |
      | /contacts/:id/edit                       | /contacts/{people}/edit            |                                                                          |
      | /contacts/:id/menu                       |                                    | a menu fragment its page loads into a context menu                       |
      | /decisions                               | /decisions                         |                                                                          |
      | /decisions/new                           | /decisions/new                     |                                                                          |
      | /decisions/:id                           | /decisions/{decisions}             |                                                                          |
      | /decisions/:id/edit                      | /decisions/{decisions}/edit        |                                                                          |
      | /decisions/:id/menu                      |                                    | a menu fragment its page loads into a context menu                       |
      | /decisions/:id/comments/:comment_id/menu |                                    | a menu fragment its page loads into a context menu                       |
      | /events                                  |                                    | the live update stream, not HTML                                         |
      | /files                                   | /files                             |                                                                          |
      | /files/:id/edit                          | /files/{share_group_files}/edit    |                                                                          |
      | /files/groups/:id/edit                   | /files/groups/{share_groups}/edit  |                                                                          |
      | /files/:id/menu                          |                                    | a menu fragment its page loads into a context menu                       |
      | /health                                  | /health                            |                                                                          |
      | /inbox                                   | /inbox                             |                                                                          |
      | /journal                                 | /journal                           |                                                                          |
      | /journal/:id/menu                        |                                    | a menu fragment its page loads into a context menu                       |
      | /links                                   | /links                             |                                                                          |
      | /links/:id/edit                          | /links/{short_links}/edit          |                                                                          |
      | /links/:id/menu                          |                                    | a menu fragment its page loads into a context menu                       |
      | /mail                                    | /mail                              |                                                                          |
      | /mail/bulk/menu                          |                                    | a menu fragment its page loads into a context menu                       |
      | /mail/settings                           | /mail/settings                     |                                                                          |
      | /mail/messages/:id/attachments/:part     |                                    | sends a mail attachment to download, not HTML                            |
      | /mail/:id/menu                           |                                    | a menu fragment its page loads into a context menu                       |
      | /notes                                   | /notes                             |                                                                          |
      | /notes/menu                              |                                    | a menu fragment its page loads into a context menu                       |
      | /notes/folders/:id                       | /notes/folders/{note_folders}      |                                                                          |
      | /notes/folders/:id/menu                  |                                    | a menu fragment its page loads into a context menu                       |
      | /notes/:id                               | /notes/{notes}                     |                                                                          |
      | /notes/:id/menu                          |                                    | a menu fragment its page loads into a context menu                       |
      | /performance                             | /performance                       |                                                                          |
      | /performance/requests                    | /performance/requests              |                                                                          |
      | /posts                                   | /posts                             |                                                                          |
      | /posts/bulk/menu                         |                                    | a menu fragment its page loads into a context menu                       |
      | /posts/new                               | /posts/new                         |                                                                          |
      | /posts/:id/analytics                     | /posts/{posts}/analytics           |                                                                          |
      | /posts/:id/edit                          | /posts/{posts}/edit                |                                                                          |
      | /posts/:id/menu                          |                                    | a menu fragment its page loads into a context menu                       |
      | /projects                                | /projects                          |                                                                          |
      | /projects/choices                        |                                    | JSON for the project picker                                              |
      | /projects/new                            | /projects/new                      |                                                                          |
      | /projects/:id                            | /projects/{projects}               |                                                                          |
      | /projects/:id/edit                       | /projects/{projects}/edit          |                                                                          |
      | /projects/:id/menu                       |                                    | a menu fragment its page loads into a context menu                       |
      | /projects/:key/tags/:name                | /projects/AXE/tags/axe-check       |                                                                          |
      | /pull-requests/:id                       | /pull-requests/{pull_requests}     |                                                                          |
      | /review                                  | /review                            |                                                                          |
      | /saved-views/palette                     |                                    | JSON for the command palette                                             |
      | /search                                  | /search                            |                                                                          |
      | /search/palette                          |                                    | JSON for the command palette                                             |
      | /services                                |                                    | redirects to the services settings tab                                   |
      | /services/:key/menu                      |                                    | a menu fragment its page loads into a context menu                       |
      | /settings/jobs                           | /settings/jobs                     |                                                                          |
      | /settings/jobs/cron/:name/menu           |                                    | a menu fragment its page loads into a context menu                       |
      | /settings/jobs/:set/:jid/menu            |                                    | a menu fragment its page loads into a context menu                       |
      | /settings/security                       | /settings/security                 |                                                                          |
      | /settings/services                       | /settings/services                 |                                                                          |
      | /settings/tagging                        | /settings/tagging                  |                                                                          |
      | /settings/webmentions                    | /settings/webmentions              |                                                                          |
      | /social                                  | /social                            |                                                                          |
      | /social/:id/menu                         |                                    | a menu fragment its page loads into a context menu                       |
      | /tags                                    |                                    | redirects to the tagging settings tab                                    |
      | /tags/private/choices                    |                                    | JSON for the tag field                                                   |
      | /tags/:name                              | /tags/{tags.name}                  |                                                                          |
      | /tags/:id/menu                           |                                    | a menu fragment its page loads into a context menu                       |
      | /tasks                                   | /tasks                             |                                                                          |
      | /tasks/bulk/menu                         |                                    | a menu fragment its page loads into a context menu                       |
      | /tasks/in-progress                       |                                    | JSON for the palette's running tasks                                     |
      | /tasks/new                               | /tasks/new                         |                                                                          |
      | /tasks/rules/:id/menu                    |                                    | a menu fragment its page loads into a context menu                       |
      | /tasks/:id                               | /tasks/{tasks}                     |                                                                          |
      | /tasks/:id/edit                          | /tasks/{tasks}/edit                |                                                                          |
      | /tasks/:id/menu                          |                                    | a menu fragment its page loads into a context menu                       |
      | /tasks/:id/comments/:comment_id/menu     |                                    | a menu fragment its page loads into a context menu                       |
      | /tasks/:id/sessions/:session_id/menu     |                                    | a menu fragment its page loads into a context menu                       |
      | /tasks/sprints/:id/menu                  |                                    | a menu fragment its page loads into a context menu                       |
      | /time                                    | /time                              |                                                                          |
      | /tokens/:id/menu                         |                                    | a menu fragment its page loads into a context menu                       |
      | /webmentions                             | /webmentions                       |                                                                          |
      | /webmentions/bulk/menu                   |                                    | a menu fragment its page loads into a context menu                       |
      | /webmentions/:id/menu                    |                                    | a menu fragment its page loads into a context menu                       |
      | /*path                                   | /nowhere                           |                                                                          |
      | /sign-in                                 |                                    | the sign-in page, which admin/sign_in.feature checks with axe signed out |
    And each page above answers with no axe breaches in light or dark
