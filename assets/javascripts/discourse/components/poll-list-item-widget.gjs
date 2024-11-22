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
import loadingSpinner from "discourse/helpers/loading-spinner";

import Poll from "./poll";

export default class PollListItemWidgetComponent extends Component {
  @service router;
  @service pollsService;
  @service siteSettings;
  @service store;
  @service appEvents;

  @tracked inFrontpage = false;
  @tracked pollUpdated = false;
  @tracked pollAttributes = {};

  @tracked poll = this.args.poll;
  @tracked post = null; // post for poll (from poll:voted event, or get from server)
  @tracked vote = null; // vote for poll (from poll:voted event)

  constructor() {
    super(...arguments);

    this.appEvents.on("poll:voted", this, this.handlePollVotedEvent);
  }

  willDestroy() {
    super.willDestroy(...arguments);

    this.appEvents.off("poll:voted", this, this.handlePollVotedEvent);
  }

  // get poll() {
  //   return this.args.poll;
  // }

  updatePollAndVotes(newPoll, newPost, newVote) {
    this.poll = newPoll;
    this.post = newPost;
    //this.votes = newVotes;
    this.vote = newVote;
  }

  get post() {
    return this.postForPoll(this.poll);
  }

  postForPoll(poll) {
    return this.pollsService.postsForPoll(poll);
  }

  async buildPollAttrs(poll, post, vote) {
    console.log("buildPollAttr", poll, post);

    const pollGroupableUserFields = this.siteSettings.groupable_user_fields;
    const pollName = poll.name;
    const pollObj = EmberObject.create(poll);
    const titleElement = poll.post_topic_title;

    let pollPost = post;

    // NOTE: 매번 가져와야 새로 그림. 원인 파악중.
    //if(!pollPost) {
      pollPost = await this.postForPoll(poll);
    //}

    console.log('buildPollAttr pollPost', pollPost);

    if(!vote) {
      const polls_votes = pollPost.get('polls_votes') || {};
      vote = polls_votes[pollName] || [];
    }

    const attrs = {
      id: `${pollName}-${pollPost.id}`,
      poll: pollObj,
      post: pollPost,
      vote,
      hasSavedVote: vote != null && vote.length > 0,
      titleHTML: titleElement, //titleElement?.outerHTML,
      groupableUserFields: (pollGroupableUserFields || "")
        .split("|")
        .filter(Boolean),
      //_postCookedWidget: helper.widget,
    };

    // console.log('attrs', attrs);

    return attrs;
  }

  // @action
  // async loadPollAttributes() {
  //   this.isFetchingPollAttributes = true;
  //   try {
  //     const attr = await Promise.all(
  //       this.polls.map((pollHash) =>
  //         this.buildPollAttrs(pollHash)
  //       )
  //     );

  //     setProperties(this, {
  //       pollAttributes: attr,
  //       isFetchingPollAttributes: false,
  //     });

  //   } catch (error) {
  //     console.error("Error loading poll attributes:", error);
  //     this.isFetchingPollAttributes = false;
  //   }
  // }

  async updatePollAttributes() {
    this.pollUpdated = false;
    const updatedAttributes = await this.buildPollAttrs(this.poll, this.post, this.vote);
    this.pollAttributes = updatedAttributes; // pollAttributes 업데이트
    this.pollUpdated = true;
  }


  async handlePollVotedEvent(poll, post, vote) {
    if (this.pollAttributes && this.pollAttributes.id === `${poll.name}-${poll.post_id}`) {
      this.updatePollAndVotes(poll, post, vote);
      await this.updatePollAttributes();
    } else {
      console.warn("No matching poll found for the event");
    }
  }

  @action
  async onDidInsert() {
    await this.updatePollAttributes();
  }

  <template>
    <div class='poll-list-item-widget' {{didInsert this.onDidInsert}}>
      {{#if this.poll}}
        {{#if this.pollUpdated}}
        <div class="poll-outer" data-poll-name={{this.poll.name}} data-poll-type={{this.poll.type}}>
          <div class="poll">
            <Poll @attrs={{this.pollAttributes}} />
          </div>
        </div>
        {{else}}
        {{loadingSpinner size="small"}}
        {{/if}}
      {{else}}
        {{loadingSpinner size="small"}}
      {{/if}}
    </div>
  </template>
}
