import Component from "@glimmer/component";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import DButton from "discourse/components/d-button";
import i18n from "discourse-common/helpers/i18n";
import Topic from "discourse/models/topic";

// param: @postId
export default class PostListTabChildDiscussionComponent extends Component {
  //@service currentUser;
  @service store;
  @service pollsService;
  @tracked comments = null;

  @action initdata() {
    //console.log('this.args', this.args);
    console.log("this.args.postId", this.args.postId);
    this.fetchPosts(this.args.postId);
  }

  async fetchPosts(postId) {
    // const post = await this.store.find("post", postId);
    const post = await this.pollsService.fetchPostById(postId);
    const topicId = post.topic_id;

    // extract post for the topic
    const topic = await Topic.find(topicId, {});
    let allPosts = topic.post_stream.posts;

    // firstly filter comments by reply_to_post_number
    let firstLevelPosts = allPosts.filter(
      (p) => p.reply_to_post_number === null
    );

    // sort by created_at
    firstLevelPosts.sort(
      (a, b) => new Date(b.created_at) - new Date(a.created_at)
    );

    // decorate posts
    firstLevelPosts.forEach((p) => {
      p.created_date = this._dateString(post.created_at);
      p.cooked_truncated = this._truncateString(
        this._stripHtmlTags(post.cooked)
      );
    });

    this.comments = firstLevelPosts;
  }

  _truncateString(str, len = 40) {
    if (str.length > len) {
      return str.slice(0, len) + "...";
    }
    return str;
  }

  _dateString(datetime) {
    return new Date(datetime).toISOString().slice(0, 10);
  }

  _stripHtmlTags(html) {
    return html.replace(/<\/?[^>]+(>|$)/g, "");
  }

  <template>
    <div class="post-list" {{didInsert this.initdata}}>
      <ul>
        {{#each this.comments as |post|}}
          <li>
            [{{post.created_date}}]
            {{post.cooked_truncated}}
          </li>
        {{/each}}
      </ul>
    </div>
  </template>
}
