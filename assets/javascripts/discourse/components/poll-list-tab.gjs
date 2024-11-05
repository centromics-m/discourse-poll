import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { fn } from "@ember/helper";
import i18n from "discourse-common/helpers/i18n";
import { service } from "@ember/service";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import PollListTabChildDiscussion from "./poll-list-tab-child-discussion";
import Topic from "discourse/models/topic";

// args: @poll
export default class PollListTabComponent extends Component {
  @service pollsService;
  @tracked selectedTab = "tab1"; // 초기 선택된 탭
  @tracked commentCount = 0;

  get postId() {
    return this.args.poll.post_id;
  }

  get tabs() {
    let tabs = [
      { id: "tab1", label: i18n("poll.admin.tab_overview"), badge: null },
      { id: "tab2", label: i18n("poll.admin.tab_data"), badge: null },
      { id: "tab3", label: i18n("poll.admin.tab_discussion"), badge: this.commentCount },
      { id: "tab4", label: i18n("poll.admin.tab_leaderboard"), badge: null },
    ];
    return tabs;
  }

  @action initData() {
    //console.log("this.args.postId", this.postId);
    this.updateCommentCount(this.postId);
  }

  async updateCommentCount(postId) {
    const post = await this.pollsService.fetchPostById(postId);
    const topicId = post.topic_id;

    const topic = await Topic.find(topicId, {});
    let allPosts = topic.post_stream.posts;

    // firstly filter comments by reply_to_post_number
    let firstLevelPosts = allPosts.filter(
      (p) => p.reply_to_post_number === null
    );

    this.commentCount = firstLevelPosts.length;
  }

  @action
  selectTab(tabId, event) {
    event.preventDefault();
    this.selectedTab = tabId; // 선택된 탭 변경
  }

  isActiveTab(selected_tab, tabId) {
    return selected_tab === tabId; // 현재 선택된 탭과 비교
  }

  <template>
    <div class="poll-list-tab-wrap" {{didInsert this.initData}}>
      <ul class="nav">
        {{#each this.tabs as |tab|}}
          <li class={{if (this.isActiveTab this.selectedTab tab.id) "active"}}>
            <a href="#" {{on "click" (fn this.selectTab tab.id)}}>{{tab.label}}
              {{#if tab.badge}}<span class='badge'>{{tab.badge}}</span>{{/if}}
            </a>
          </li>
        {{/each}}
      </ul>

      <div class="tab-content">
        {{#if (this.isActiveTab this.selectedTab "tab1")}}
          {{{@poll.post_topic_overview}}}
        {{/if}}

        {{#if (this.isActiveTab this.selectedTab "tab2")}}
          {{{@poll.poll_data_link}}}
        {{/if}}

        {{#if (this.isActiveTab this.selectedTab "tab3")}}
          <PollListTabChildDiscussion @postId={{@poll.post_id}} />
        {{/if}}

        {{#if (this.isActiveTab this.selectedTab "tab4")}}
          <p>Content for Tab 4</p>
        {{/if}}
      </div>
    </div>
  </template>
}
