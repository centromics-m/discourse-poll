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
  @service siteSettings;

  // Fetch and update polls
  get getPolls() {
    return this.pollsService.polls;
  }

  @action
  fetchPolls(element) {
    this.getPolls.then((result) => {
      let polls = result.polls.filter((poll) => poll.public === true);
      polls = polls.map ((poll) => {
        return {
          ...poll,
          created_date: new Date(poll.created_at).toISOString().slice(0, 10),
          post_topic_title_truncated: this._truncateString(poll.post_topic_title, 45),
        };
      });
      if (polls.length > 0) {
        this.poll = polls[0];
      }
      this.polls = polls;
      console.log('Fetched polls:', polls);
    });
  }

  get isFrontpage() {
    return this.router.currentRouteName === 'discovery.latest' ||
      this.router.currentRouteName === 'index';
  }

  get showInFrontend() {
    return this.isFrontpage && this.siteSettings.poll_show_in_frontpage;
  }

  _truncateString(str, len = 40) {
    if (str.length > len) {
      return str.slice(0, len) + "...";
    }
    return str;
  }


  <template>
    {{#if this.showInFrontend}}
    <div id="poll-main" {{didInsert this.fetchPolls}}>
      <h1 class="cv-title"><span class="black white-text">{{i18n "poll.admin.expectation"}}</span></h1>
      <section>
      {{#if this.polls.length}}
          {{#each this.polls as |poll index|}}
        <article class="item">
            <i class="vertical-line"></i>
            <h2 class="item-date">{{poll.created_date}}</h2>
            <div class="card-panel">
              <h3 class="card-title"><a href="{{poll.post_url}}">{{poll.post_topic_title_truncated}} - {{poll.title}}</a></h3>
            </div>
          </article>
          {{/each}}
        <div class="last-item">
          <i class="vertical-line"></i>
        </div>
      {{else}}
        <p>{{i18n "poll.admin.none"}}</p>
      {{/if}}
      </section>
    </div>
    {{/if}}
  </template>
}
