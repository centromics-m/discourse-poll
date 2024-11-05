import Component from "@glimmer/component";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { fn } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import DButton from "discourse/components/d-button";
import i18n from "discourse-common/helpers/i18n";
import Topic from "discourse/models/topic";

// param: @postId
export default class PostListTabChildDiscussionComponent extends Component {
  @service pollsService;
  @tracked comments = null;

  static #postCache = new Map();

  @action initdata() {
    //console.log('this.args', this.args);
    //console.log("this.args.postId", this.args.postId);
    this.fetchPosts(this.args.postId);
  }

  async fetchPosts(postId) {
    //const post = await this.pollsService.fetchPostById(postId);
    const post = await this._fetchPostWithCache(postId);
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
      p.cooked_truncated = this._truncateString(this._stripHtmlTags(post.cooked, 80));
    });

    this.comments = firstLevelPosts;
  }

  @action
  onPostPageClicked(postId) {
    this._onPostPageClicked(postId);
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

  async _fetchPostWithCache(postId) {
    //console.log('postCache', this.postCache);
    const cacheEntry = PostListTabChildDiscussionComponent.#postCache.get(postId);
    const now = Date.now();

    // 10분(600,000ms) 이내에 캐싱된 데이터가 있다면 사용
    if (cacheEntry && (now - cacheEntry.timestamp < 600000)) {
      return cacheEntry.data;
    }

    // 그렇지 않다면 새로 가져와 캐시에 저장
    const post = await this.pollsService.fetchPostById(postId);
    PostListTabChildDiscussionComponent.#postCache.set(postId, { data: post, timestamp: now });
    return post;
  }

  async _onPostPageClicked(postId) {
    //const post = await this.pollsService.fetchPostById(postId);
    const post = await this._fetchPostWithCache(postId);
    const url = '/t/' + post.topic_slug;
    document.location.href = url;
  }

  <template>
    <div class="post-list" {{didInsert this.initdata}}>
      <ul>
        {{#each this.comments as |post|}}
          <li>
            [{{post.created_date}}] {{post.cooked_truncated}}
          </li>
        {{/each}}
      </ul>
       <DButton class="widget-button" @action={{fn this.onPostPageClicked @postId}}>
        {{i18n "poll.poll_list_widget.goto_comment"}}
       </DButton>
    </div>
  </template>
}
