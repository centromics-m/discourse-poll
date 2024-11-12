import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import CategoryChooser from "select-kit/components/category-chooser";
import { htmlSafe } from "@ember/template";
import Category from "discourse/models/category";

import PollListItemWidget from "./poll-list-item-widget"
import PollListTab from "./poll-list-tab";

const dateOptions = {
  year: "numeric",
  month: "short",
  day: "numeric",
};

export default class PollListWidgetComponent extends Component {
  @tracked poll;
  @tracked polls = [];
  @tracked inFrontpage = false;
  @service router;
  @service pollsService;
  @service siteSettings;
  @tracked categoryId = this.pollsService.category;
  @tracked currentCategory = null;

  constructor() {
    super(...arguments);
    this.loadCurrentCategory();
  }

  async loadCurrentCategory() {
    this.currentCategory = await Category.findById(this.categoryId);
  }

  // Fetch and update polls
  get getPolls() {
    return this.pollsService.polls;
  }

  @action
  fetchPolls(element) {
    this.getPolls.then((result) => {
      let polls = result.polls.filter((poll) => poll.public === true);
      // polls = polls.map((poll) => {
      //   return {
      //     ...poll,
      //     post_topic_title_truncated: this.truncateString(poll.post_topic_title, 45),
      //   };
      // });
      if (polls.length > 0) {
        this.poll = polls[0];
      }
      this.polls = polls;
      console.log("Fetched polls:", polls);
    });
  }

  @action
  getCloseDateFormat(date_o) {
    return htmlSafe(
      '<span class="close-date">' + this.dateFormat(date_o) + "</span>"
    );
  }

  @action
  getOpenDateFormat(date_o) {
    return htmlSafe(
      '<span class="open-date">' + this.dateFormat(date_o) + "</span>"
    );
  }

  @action
  changeCategory(category) {
    this.pollsService.setCategory(category);
    this.fetchPolls();
    this.categoryId = category;

    this.loadCurrentCategory();
  }

  get isFrontpage() {
    return (
      this.router.currentRouteName === "discovery.latest" ||
      this.router.currentRouteName === "index"
    );
  }

  get showInFrontend() {
    return this.isFrontpage && this.siteSettings.poll_show_in_frontpage;
  }

  dateFormat(date_o) {    
    if(date_o === undefined)
      return '';
    return new Date(date_o).toLocaleDateString(I18n.currentLocale(), dateOptions);
  }

  truncateString(str, len = 40) {
    if (str.length > len) {
      return str.slice(0, len) + "...";
    }
    return str;
  }

  datePercentage(startDate, endDate) {
    const d1 = new Date(startDate);
    const d2 = new Date(endDate);

    const timeDifference = Math.abs(d2 - d1);
    const dayDifference = Math.ceil(timeDifference / (1000 * 60 * 60 * 24));

    const d3 = new Date(startDate);
    const d4 = new Date();

    const timeDifference2 = Math.abs(d4 - d3);
    const dayDifference2 = Math.ceil(timeDifference2 / (1000 * 60 * 60 * 24));

    const numValue = Number(dayDifference2);
    const numTotal = Number(dayDifference);

    // console.log(numValue)
    // console.log(numTotal)

    if (isNaN(numValue) || isNaN(numTotal) || numTotal === 0) {
      return 0;
    }

    const percentage = (numValue / numTotal) * 100;

    return_value = Math.round(percentage);

    if(return_value >= 95) {
      return_value = 95;
    }

    return return_value;
 }

  <template>
    {{#if this.showInFrontend}}
      <div class="poll-widget-main" {{didInsert this.fetchPolls}}>
        <h1 class="cv-title">
          <span class="black white-text">
            <CategoryChooser
              @value={{this.categoryId}}
              @onChange={{this.changeCategory}}
              class="leaderboard__period-chooser"
            />
          </span>
        </h1>
        <a href="{{this.currentCategory.url}}" class="poll-category-more">
          {{this.currentCategory.name}} {{i18n "poll.admin.more"}}
        </a>
        <section>
          {{#if this.polls.length}}
            {{#each this.polls as |poll index|}}
              <article class="item">
                <i class="vertical-line"></i>
                <h2 class="card-title">
                  <a href="{{poll.post_url}}">{{this.truncateString poll.post_topic_title 45}}{{if poll.title poll.title}}</a>
                </h2>
                <div class="card-panel">
                  <h3 class="item-date">
                    {{(this.getOpenDateFormat poll.created_at)}}
                    {{#if poll.close}}
                      <span class="close-percentage" data="">
                        <span class="arrow" style="left: {{this.datePercentage poll.created_at poll.close}}%">&nbsp;</span>
                      </span>
                      {{this.getCloseDateFormat poll.close}}
                    {{/if}}
                   </h3>
                  <div class='poll-list-widget-wrap'>
                    {{!-- {{{poll.post_topic_poll}}} --}}
                    <PollListItemWidget @poll={{poll}} />
                  </div>
                  <PollListTab @poll={{poll}} />
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
