import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsPolls extends DiscourseRoute {
  model() {
    if (!this.currentUser?.admin) {
      return { model: null };
    }

    //return [{id: 1, title: 'Grand Old Mansion',period: 'Veruca Salt'},{id: 2,title: 'asdgsdg', period: 'asdg'}];


    return ajax("/polls/poll_list.json").then((model) => {
      return model;
    });
   }
}
