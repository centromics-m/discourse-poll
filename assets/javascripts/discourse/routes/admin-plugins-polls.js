import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsPolls extends DiscourseRoute {

  async model(params) {
    if (!this.currentUser?.admin) {
      return { model: null };
    }
    const page = params.page || 1;

    // AJAX 요청으로 데이터를 가져옵니다.
    const response = await ajax(`/polls/poll_admin_list.json?page=${page}`);
    const { polls, total_pages } = response.poll_list;

    return {
      polls,
      totalPages: total_pages,
    };
  }

  setupController(controller, model) {
    controller.setProperties({
      polls: model.polls,
      totalPages: model.totalPages,
      currentPage: 1,
    });
  }
}
