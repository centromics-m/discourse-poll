import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { fn } from "@ember/helper";
import i18n from "discourse-common/helpers/i18n";
import PollListTabChildDiscussion from "./poll-list-tab-child-discussion";

export default class PollListTabComponent extends Component {
    @tracked selectedTab = 'tab1'; // 초기 선택된 탭

    tabs = [
        { id: 'tab1', label: i18n("poll.admin.tab_overview")},
        { id: 'tab2', label: i18n("poll.admin.tab_data")},
        { id: 'tab3', label: i18n("poll.admin.tab_discussion")},
        { id: 'tab4', label: i18n("poll.admin.tab_leaderboard")}
    ];

    @action
    selectTab(tabId, event) {
      event.preventDefault();
        this.selectedTab = tabId; // 선택된 탭 변경
    }

    isActiveTab(selected_tab, tabId) {
        return selected_tab === tabId; // 현재 선택된 탭과 비교
    }


<template>
  <ul class="nav">
{{#each this.tabs as |tab|}}
<li class={{if (this.isActiveTab  this.selectedTab  tab.id) "active"}}>
    <a href="#" {{on "click" (fn this.selectTab tab.id)}}>{{tab.label}}</a>
</li>
{{/each}}
</ul>

    <div class="tab-content">
      {{#if (this.isActiveTab this.selectedTab "tab1")}}
        {{{@poll.post_topic_overview}}}
      {{/if}}

      {{#if (this.isActiveTab this.selectedTab "tab2")}}
        <p>Content for Tab 2</p>
      {{/if}}

      {{#if (this.isActiveTab this.selectedTab "tab3")}}
        <PollListTabChildDiscussion @postId={{@poll.post_id}} />
      {{/if}}

      {{#if (this.isActiveTab this.selectedTab "tab4")}}
        <p>Content for Tab 4</p>
      {{/if}}
            </div>
  </template>
}
