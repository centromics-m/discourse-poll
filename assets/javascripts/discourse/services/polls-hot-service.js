import Service from "@ember/service";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class pollsHotService extends Service {
  @service store;

  get polls() {
    return ajax("/polls/poll_list_home.json").then(
      (response) => {
				//console.log(response);
        return response;
      }
    );
  }
}
