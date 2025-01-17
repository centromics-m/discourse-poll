import Service from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class pollsService extends Service {
  @service store;
  @tracked category = 4;

  setCategory(category) {
    this.set("category", category);
  }

  get polls() {
    return ajax("/polls/poll_list.json?category=" + this.category).then(
      (response) => {
				//console.log(response);
        return response;
      }
    );
  }

  postsForPoll(poll) {
    return this.fetchPostById(poll.post_id).then((response) => {
      return response;
    });
  }

  async fetchPostById(post_id) {
    try {
      const post = await this.store.find("post", post_id);
      return post;
    } catch (error) {
      console.error("Error fetching post:", error);
    }
  }
}
