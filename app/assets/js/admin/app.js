import "../../css/admin.css";
import { setupAutosubmit } from "./autosubmit.js";
import { setupBoardDrag } from "./board_drag.js";
import { setupBulk } from "./bulk.js";
import { setupCadences } from "./cadence.js";
import { setupCalendars } from "./calendar.js";
import { setupCommentAdds } from "./comment_add.js";
import { setupCommitImports } from "./commits.js";
import { setupConfirms } from "./confirm.js";
import { setupContextMenus } from "./context_menu.js";
import { setupDialogs } from "./dialog.js";
import { setupEditNotes } from "./edit_note.js";
import { setupFileDrops } from "./file_drop.js";
import { setupJournals } from "./journal.js";
import { setupKeys } from "./keys.js";
import { setupLinkForms } from "./link_form.js";
import { setupLive } from "./live.js";
import { setupMailDrag } from "./mail_drag.js";
import { setupMailEditors } from "./mail_editor.js";
import { setupMarkdownEditors } from "./markdown_editor.js";
import { setupMorphForms } from "./morph_form.js";
import { setupPalette } from "./palette.js";
import { setupPersonDrawer } from "./person_drawer.js";
import { setupPersonFinder } from "./person_finder.js";
import { setupPersonForms } from "./person_form.js";
import { setupPools } from "./pools.js";
import { setupPostEditors } from "./post_editor.js";
import { setupPostSyndication } from "./post_syndication.js";
import { setupProjectEditors } from "./project_editor.js";
import { setupProjectPicks } from "./project_pick.js";
import { setupRecordKeys } from "./record_key.js";
import { setupAccountPickers } from "./social_account_picker.js";
import { setupSocialComposers } from "./social_composer.js";
import { setupTagFields } from "./tag_field.js";
import { setupTaskOrder } from "./task_order.js";
import { setupTaskPanel } from "./task_panel.js";
import { setupToasts } from "./toast.js";
import { setupTracked } from "./tracked.js";
import { setupWorkForms } from "./work_form.js";

const STEPS = [
  setupAccountPickers,
  setupAutosubmit,
  setupBoardDrag,
  setupBulk,
  setupCadences,
  setupCalendars,
  setupCommentAdds,
  setupCommitImports,
  setupConfirms,
  setupContextMenus,
  setupDialogs,
  setupEditNotes,
  setupFileDrops,
  setupJournals,
  setupKeys,
  setupLinkForms,
  setupMailDrag,
  setupMailEditors,
  setupMarkdownEditors,
  setupPalette,
  setupPersonDrawer,
  setupPersonFinder,
  setupPersonForms,
  setupPools,
  setupPostEditors,
  setupPostSyndication,
  setupProjectEditors,
  setupProjectPicks,
  setupRecordKeys,
  setupSocialComposers,
  setupTagFields,
  setupTaskOrder,
  setupTaskPanel,
  setupToasts,
  setupWorkForms,
];

function setup() {
  for (const step of STEPS) {
    try {
      step();
    } catch (error) {
      reportError(error);
    }
  }
}

setup();
setupLive();
setupMorphForms();
setupTracked();
document.addEventListener("admin:morphed", setup);
