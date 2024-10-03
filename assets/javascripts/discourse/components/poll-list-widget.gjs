import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import i18n from "discourse-common/helpers/i18n";

export default class PollListWidgetComponent extends Component {
  @tracked poll;
  @tracked polls = [];
  @tracked inFrontpage = false;
  @service router;
  @service pollsService;

  // Fetch and update polls
  get getPolls() {
    return this.pollsService.polls;
  }

  @action
  fetchPolls(element) {
    this.getPolls.then((result) => {
      let polls = result.polls.filter((poll) => poll.status === "open");
      this.polls = polls;
      if (polls.length > 0) {
        this.poll = polls[0];
      }
      console.log('Fetched polls:', polls);
    });
  }

  get isFrontpage() {
    return this.router.currentRouteName === 'discovery.latest' ||
      this.router.currentRouteName === 'index';
  }

  <template>
    {{#if this.isFrontpage}}
    <div class="poll-widget-list" {{didInsert this.fetchPolls}}>
      <h3>Active polls</h3>
      <br>
      {{#if this.polls.length}}
        <ul>
          {{#each this.polls as |poll|}}
            <li>Poll: <a href="{{poll.post_url}}">{{poll.post_topic_title}} - {{poll.title}}</a></li>
          {{/each}}
        </ul>
      {{else}}
        <p>{{i18n "poll.admin.none"}}</p>
      {{/if}}
    </div>
    {{/if}}
  </template>

}
