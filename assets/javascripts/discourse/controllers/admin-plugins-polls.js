import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "I18n";

export default Controller.extend({
  modal: service(),
  dialog: service(),
  toasts: service(),
  creatingNew: false,

  @discourseComputed("model.polls.@each.updatedAt")
  sortedPolls(polls) {
    return polls?.sortBy("updatedAt").reverse() || [];
  },

  @action
  destroyPoll(poll) {
    this.dialog.deleteConfirm({
      message: I18n.t("gamification.leaderboard.confirm_destroy"),
      didConfirm: () => {
        return ajax(
          `/admin/plugins/gamification/leaderboard/${leaderboard.id}`,
          {
            type: "DELETE",
          }
        )
          .then(() => {
            this.toasts.success({
              duration: 3000,
              data: {
                message: I18n.t("gamification.leaderboard.delete_success"),
              },
            });
            this.model.polls.removeObject(poll);
          })
          .catch(popupAjaxError);
      },
    });
  },


  parseDate(date) {
    if (date) {
      // using the format YYYY-MM-DD returns the previous day for some timezones
      return date.replace(/-/g, "/");
    }
  },
});
