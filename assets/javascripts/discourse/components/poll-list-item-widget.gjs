import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { action, computed, setProperties  } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import i18n from "discourse-common/helpers/i18n";
import { fn } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import EmberObject from "@ember/object";
import WidgetGlue from "discourse/widgets/glue";
import { getRegister } from "discourse-common/lib/get-owner";
import { withPluginApi } from 'discourse/lib/plugin-api';
import { bind, observes } from "discourse-common/utils/decorators";
import { getOwner } from "@ember/application";

import PollSimple from "./poll-simple";

export default class PollListItemWidgetComponent extends Component {
  @service router;
  @service pollsService;
  @service siteSettings;
  @service store;

  @tracked inFrontpage = false;
  @tracked pollUpdated = false;
  @tracked pollAttributes = {};

  get poll() {
    return this.args.poll;
  }

  get post() {
    return this.postForPoll(this.poll);
    //return '11';
  }

  postForPoll(poll) {
    return this.pollsService.postsForPoll(poll);
  }

  async buildPollAttrs(poll) {
    const pollGroupableUserFields = this.siteSettings.groupable_user_fields;
    const pollName = poll.name;
    const pollPost = await this.postForPoll(poll);
    const vote = [];
    const titleElement = 'title'; //poll.title;

    //console.log('buildPollAttrs pollPost', pollPost);

    const attrs = {
      id: `${pollName}-${pollPost.id}`,
      post: pollPost,
      poll: EmberObject.create(poll),
      vote,
      hasSavedVote: vote.length > 0,
      titleHTML: titleElement, //titleElement?.outerHTML,
      groupableUserFields: (pollGroupableUserFields || "")
        .split("|")
        .filter(Boolean),
      //_postCookedWidget: helper.widget,
    };

    return attrs;
  }

  @action
  async loadPollAttributes() {
    this.isFetchingPollAttributes = true;
    try {
      const attr = await Promise.all(this.polls.map(
        (pollHash) => this.buildPollAttrs(pollHash)
      ));
      //console.log('loadPollAttributes pollAttributes', attr);
      setProperties(this, {
        pollAttributes: attr,
        isFetchingPollAttributes: false,
      });
    } catch (error) {
      console.error("Error loading poll attributes:", error);
      this.isFetchingPollAttributes = false;
    }
  }

  updatePollAttributes() {
    //console.log('calling pollAttributes result');
    this.pollUpdated = false;
    return this.buildPollAttrs(this.poll).then((result) => {
      //console.log('finished pollAttributes result', result);
      this.pollUpdated = true;
      this.pollAttributes = result;
      return result;
    });
  }

  @action
  onDidInsert() {
    //console.log('ondidinsert');
    this.updatePollAttributes();
  }

  <template>
    <div class='poll-list-item-widget' {{didInsert this.onDidInsert}}>
      {{#if this.poll}}
        <p>{{this.poll.post_topic_title}} [{{this.poll.name}}]</p>
        {{#if this.pollUpdated}}
        <div class="poll-outer" data-poll-name={{this.poll.name}} data-poll-type={{this.poll.type}}>
          <div class="poll">
          <PollSimple @attrs={{this.pollAttributes}} />
          </div>
        </div>
        {{else}}
        <p>Poll preparing</p>
        {{/if}}
      {{else}}
        <p>Loading poll...</p>
      {{/if}}
    </div>
  </template>
}
