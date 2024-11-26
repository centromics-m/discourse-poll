import Component from "@ember/component";
import EmberObject, { action } from "@ember/object";
import { gt, or } from "@ember/object/computed";
import { service } from "@ember/service";
import { observes } from "@ember-decorators/object";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export const BAR_CHART_TYPE = "bar";
export const PIE_CHART_TYPE = "pie";

export const REGULAR_POLL_TYPE = "regular";
export const NUMBER_POLL_TYPE = "number";
export const MULTIPLE_POLL_TYPE = "multiple";
export const RANKED_CHOICE_POLL_TYPE = "ranked_choice";

const ALWAYS_POLL_RESULT = "always";
const VOTE_POLL_RESULT = "on_vote";
const CLOSED_POLL_RESULT = "on_close";
const STAFF_POLL_RESULT = "staff_only";

export default class PollUiBuilderModal extends Component {
  @service siteSettings;

  // by etna
  // mode = this.model.mode ?? 'default'; // default or standalone
  // onInsertPoll = this.model.insertPoll;

  showAdvanced = false;
  pollType = REGULAR_POLL_TYPE;
  pollTitle;
  pollOptions = [EmberObject.create({ value: "", correct: false})];
  pollOptionsText = "";
  pollDataLinks = [EmberObject.create({ url: "", title: "", content: ""})];
  pollMin = 1;
  pollMax = 2;
  pollStep = 1;
  pollGroups;
  pollAutoClose;
  pollResult = ALWAYS_POLL_RESULT;
  score = 100;
  defaultScore = [0,100,200,300,400,500];
  chartType = BAR_CHART_TYPE;
  publicPoll = this.siteSettings.poll_default_public;

  didReceiveAttrs() {
    this._super(...arguments);
    console.log('this.model', this.model);

    // NOTE: post editor에서 호출하지 않고 외부에서 호출하면 this.model == this.model.model임.. (원 소스의 잠재적 오류로 보임)
    if(this.model.model) {
      this.model = this.model.model;
    }

    const polldata = this.model.polldata;

    if(polldata.pollType != undefined) {
      this.set('pollType', polldata.pollType);
    }
    if(polldata.pollTitle != undefined) {
      this.pollTitle = polldata.pollTitle;
    }
    if(polldata.pollOptions != undefined) {
      console.log('polldata.pollOptions', polldata.pollOptions)
      this.pollOptions = polldata.pollOptions?.map((option) => {
        return EmberObject.create({...option, value: option.html});
      });
      console.log('this.pollOptions', this.pollOptions)

    }
    if(polldata.pollOptionsText != undefined) {
      this.pollOptionsText = polldata.pollOptionsText;
    }
    // if(polldata.pollDataLinks != undefined) {
    //   console.log('polldata.pollDataLinks', polldata.pollDataLinks);
    //   if(polldata.pollDataLinks == null)
    //     polldata.pollDataLinks = [];
    //   this.pollOptions = polldata.pollDataLinks.map((option) => {
    //     EmberObject.create({ url: option.url, title: option.title, content: option.content });
    //   });
    // }
    if(polldata.pollMin != undefined) { this.pollMin = polldata.pollMin; }
    if(polldata.pollMax != undefined) { this.pollMax = polldata.pollMax; }
    if(polldata.pollStep != undefined) { this.pollStep = polldata.pollStep; }
    if(polldata.pollGroups != undefined) { this.pollGroups = polldata.pollGroups; }
    if(polldata.pollAutoClose != undefined) { this.pollAutoClose = polldata.pollAutoClose; }
    if(polldata.pollResult != undefined) { this.pollResult = polldata.pollResult; }
    if(polldata.pollResult != undefined) { this.pollResult = polldata.pollResult; }
    if(polldata.publicPoll != undefined) { this.pollResult = polldata.publicPoll; }

    //console.log('this.model.model.mode', this.model.model);
    console.log('this.model.mode', this.model.mode);
    console.log('this.model', this.model);
  }

  // get model() {
  //   console.log('this.modelthis.model', this.args);
  //   return this.args.model;
  // }

  @or("showAdvanced", "isNumber") showNumber;
  @or("showAdvanced", "isRankedChoice") showRankedChoice;
  @gt("pollOptions.length", 1) canRemoveOption;
  @gt("pollDataLinks.length", 1) canRemoveDataLink;
  @or("isRankedChoice", "isRegular") rankedChoiceOrRegular;
  @or("isRankedChoice", "isNumber") rankedChoiceOrNumber;

  @discourseComputed("currentUser.staff")
  pollResults(staff) {
    const options = [
      {
        name: I18n.t("poll.ui_builder.poll_result.always"),
        value: ALWAYS_POLL_RESULT,
      },
      {
        name: I18n.t("poll.ui_builder.poll_result.vote"),
        value: VOTE_POLL_RESULT,
      },
      {
        name: I18n.t("poll.ui_builder.poll_result.closed"),
        value: CLOSED_POLL_RESULT,
      },
    ];

    if (staff) {
      options.push({
        name: I18n.t("poll.ui_builder.poll_result.staff"),
        value: STAFF_POLL_RESULT,
      });
    }

    return options;
  }

  @discourseComputed("pollType")
  isRegular(pollType) {
    return pollType === REGULAR_POLL_TYPE;
  }

  @discourseComputed("pollType")
  isNumber(pollType) {
    return pollType === NUMBER_POLL_TYPE;
  }

  @discourseComputed("pollType")
  isMultiple(pollType) {
    return pollType === MULTIPLE_POLL_TYPE;
  }

  @discourseComputed("pollType")
  isRankedChoice(pollType) {
    return pollType === RANKED_CHOICE_POLL_TYPE;
  }

  @discourseComputed("pollOptions.@each.value")
  pollOptionsCount(pollOptions) {
    return (pollOptions || []).filter((option) => option.value.length > 0)
      .length;
  }

  @discourseComputed("pollDataLinks.@each.value")
  pollDataLinksCount(pollDataLinks) {
    return (pollDataLinks || []).filter((dataLink) => dataLink.url.length > 0)
      .length;
  }

  @discourseComputed("site.groups")
  siteGroups(groups) {
    // prevents group "everyone" to be listed
    return groups.filter((g) => g.id !== 0);
  }

  @discourseComputed("chartType", "pollType")
  isPie(chartType, pollType) {
    return pollType !== NUMBER_POLL_TYPE && chartType === PIE_CHART_TYPE;
  }

  @observes("pollType", "pollOptionsCount")
  _setPollMinMax() {
    if (this.isMultiple) {
      if (
        this.pollMin <= 0 ||
        this.pollMin >= this.pollMax ||
        this.pollMin >= this.pollOptionsCount
      ) {
        this.set("pollMin", this.pollOptionsCount > 0 ? 1 : 0);
      }

      if (
        this.pollMax <= 0 ||
        this.pollMin >= this.pollMax ||
        this.pollMax > this.pollOptionsCount
      ) {
        this.set("pollMax", this.pollOptionsCount);
      }
    } else if (this.isNumber) {
      this.set("pollMax", this.siteSettings.poll_maximum_options);
    }
  }

  @discourseComputed(
    "pollType",
    "pollResult",
    "publicPoll",
    "pollTitle",
    "pollOptions.@each.value",
    "pollDataLinks.@each.value",
    "pollMin",
    "pollMax",
    "pollStep",
    "pollGroups",
    "pollAutoClose",
    "score",
    "chartType",
  )
  pollOutput(
    pollType,
    pollResult,
    publicPoll,
    pollTitle,
    pollOptions,
    pollDataLinks,
    pollMin,
    pollMax,
    pollStep,
    pollGroups,
    pollAutoClose,
    score,
    chartType
  ) {
    let pollHeader = "[poll";
    let output = "";

    let match = null;
    if(this.model.toolbarEvent) {
      match = this.model.toolbarEvent
      .getText()
      .match(/\[poll(\s+name=[^\s\]]+)*.*\]/gim);
    }

    if (match) {
      pollHeader += ` name=poll${match.length + 1}`;
    }

    let step = pollStep;
    if (step < 1) {
      step = 1;
    }

    if (pollType) {
      pollHeader += ` type=${pollType}`;
    }
    if (pollResult) {
      pollHeader += ` results=${pollResult}`;
    }
    if (pollMin && pollType !== REGULAR_POLL_TYPE) {
      pollHeader += ` min=${pollMin}`;
    }
    if (pollMax && pollType !== REGULAR_POLL_TYPE) {
      pollHeader += ` max=${pollMax}`;
    }
    if (pollType === NUMBER_POLL_TYPE) {
      pollHeader += ` step=${step}`;
    }
    pollHeader += ` public=${publicPoll ? "true" : "false"}`;
    if (chartType && pollType !== NUMBER_POLL_TYPE) {
      pollHeader += ` chartType=${chartType}`;
    }
    if (pollGroups && pollGroups.length > 0) {
      pollHeader += ` groups=${pollGroups}`;
    }
    if (pollAutoClose) {
      pollHeader += ` close=${pollAutoClose.toISOString()}`;
    }

    if (score) {
      pollHeader += ` score=${score}`;
    }

    pollHeader += "]";
    output += `${pollHeader}\n`;

    if (pollTitle) {
      output += `# ${pollTitle.trim()}\n`;
    }

    if (pollOptions.length > 0 && pollType !== NUMBER_POLL_TYPE) {
      pollOptions.forEach((option) => {
        if (option.value.length > 0) {
          output += `* ${option.value.trim()}`;
          if(option.correct) {
            output += ' [correct]';
        }
        output +="\n";
        }
      });
    }

    output += "[/poll]\n";

    if (pollDataLinks.length > 0 ) {
      output += "[poll_data_link]\n";

      pollDataLinks.forEach((dataLink) => {
        if (dataLink.url.length > 0) {
          output += `[${dataLink.title}](${dataLink.url})\n`;

          if(dataLink.content!='') {
            output +=`${dataLink.content}`;
          }
        }
      });

      output += "\n[/poll_data_link]\n";
    }

    return output;
  }

  @discourseComputed(
    "pollType",
    "pollResult",
    "publicPoll",
    "pollTitle",
    "pollOptions.@each.value",
    "pollDataLinks.@each.value",
    "pollMin",
    "pollMax",
    "pollStep",
    "pollGroups",
    "pollAutoClose",
    "score",
    "chartType",
  )
  pollOutputAsHash(
    pollType,
    pollResult,
    publicPoll,
    pollTitle,
    pollOptions,
    pollDataLinks,
    pollMin,
    pollMax,
    pollStep,
    pollGroups,
    pollAutoClose,
    score,
    chartType
  ) {
    // console.log(    pollType,
    //   pollResult,
    //   publicPoll,
    //   pollTitle,
    //   pollOptions,
    //   pollDataLinks,
    //   pollMin,
    //   pollMax,
    //   pollStep,
    //   pollGroups, // undefined
    //   pollAutoClose, // undefined
    //   score,
    //   chartType)

    const data = {
      pollType,
      pollResult,
      publicPoll,
      pollTitle: pollTitle?.trim() || '',
      pollMin,
      pollMax,
      pollStep: (!pollStep || pollStep <= 0 ? 1 : pollStep),
      pollGroups,
      pollAutoClose: pollAutoClose?.toISOString(),
      score,
      chartType,
      pollDataLinks,
    };

    let match = null;
    if(this.model.toolbarEvent) {
      match = this.model.toolbarEvent
      .getText()
      .match(/\[poll(\s+name=[^\s\]]+)*.*\]/gim);
    }

    let name = 'poll';
    if (match) {
      name = `poll${match.length + 1}`;
    }

    data['name'] = name;

    // text로도..
    data['pollOutput'] = this.pollOutput;

    return data;
  }

  @discourseComputed("isNumber", "pollOptionsCount")
  minNumOfOptionsValidation(isNumber, pollOptionsCount) {
    let options = { ok: true };

    if (!isNumber) {
      if (pollOptionsCount < 1) {
        return EmberObject.create({
          failed: true,
          reason: I18n.t("poll.ui_builder.help.options_min_count"),
        });
      }

      if (pollOptionsCount > this.siteSettings.poll_maximum_options) {
        return EmberObject.create({
          failed: true,
          reason: I18n.t("poll.ui_builder.help.options_max_count", {
            count: this.siteSettings.poll_maximum_options,
          }),
        });
      }
    }

    return EmberObject.create(options);
  }



  @discourseComputed("pollOptions.@each.value")
  showMinNumOfOptionsValidation(pollOptions) {
    return pollOptions.length !== 1 || pollOptions[0].value !== "";
  }

  @discourseComputed("pollDataLinks.@each.value")
  showMinNumOfDataLinksValidation(dataLinks) {
    return dataLinks.length !== 1 || dataLinks[0].url !== "";
  }

  @discourseComputed(
    "isMultiple",
    "pollOptionsCount",
    "isNumber",
    "pollMin",
    "pollMax",
    "pollStep"
  )
  minMaxValueValidation(
    isMultiple,
    pollOptionsCount,
    isNumber,
    pollMin,
    pollMax,
    pollStep
  ) {
    pollMin = parseInt(pollMin, 10) || 0;
    pollMax = parseInt(pollMax, 10) || 0;
    pollStep = parseInt(pollStep, 10) || 0;

    if (pollMin < 0) {
      return EmberObject.create({
        failed: true,
        reason: I18n.t("poll.ui_builder.help.invalid_min_value"),
      });
    }

    if (pollMax < 0 || (isMultiple && pollMax > pollOptionsCount)) {
      return EmberObject.create({
        failed: true,
        reason: I18n.t("poll.ui_builder.help.invalid_max_value"),
      });
    }

    if (pollMin > pollMax) {
      return EmberObject.create({
        failed: true,
        reason: I18n.t("poll.ui_builder.help.invalid_values"),
      });
    }

    if (isNumber) {
      if (pollStep < 1) {
        return EmberObject.create({
          failed: true,
          reason: I18n.t("poll.ui_builder.help.min_step_value"),
        });
      }

      const optionsCount = (pollMax - pollMin + 1) / pollStep;

      if (optionsCount < 1) {
        return EmberObject.create({
          failed: true,
          reason: I18n.t("poll.ui_builder.help.options_min_count"),
        });
      }

      if (optionsCount > this.siteSettings.poll_maximum_options) {
        return EmberObject.create({
          failed: true,
          reason: I18n.t("poll.ui_builder.help.options_max_count", {
            count: this.siteSettings.poll_maximum_options,
          }),
        });
      }
    }

    return EmberObject.create({ ok: true });
  }

  @discourseComputed("minMaxValueValidation", "minNumOfOptionsValidation")
  disableInsert(minMaxValueValidation, minNumOfOptionsValidation) {
    return !minMaxValueValidation.ok || !minNumOfOptionsValidation.ok;
  }

  _comboboxOptions(startIndex, endIndex) {
    return [...Array(endIndex - startIndex).keys()].map((number) => ({
      value: number + startIndex,
      name: number + startIndex,
    }));
  }

  @action
  onOptionsTextChange(e) {
    this.set(
      "pollOptions",
      e.target.value.split("\n").map((value) => EmberObject.create({ value }))
    );
  }

  @action
  async insertPoll() {
    console.log('poll ui builder this.model', this.model);
    // original code
    if(this.model.mode == undefined || this.model.mode == 'default' || this.model.mode == '') {
      this.model.toolbarEvent.addText(this.pollOutput);
      this.closeModal();

    // for election plugin
    } else {
      console.log('this.pollOutputAsHash', this.pollOutputAsHash);

      if(this.model.onInsertPoll) {
        const _this = this.model._this; // parent component
        const topicId = this.model.topicId;
        const categoryId = this.model.categoryId;
        const position = this.model.position;
        const data = this.pollOutputAsHash;

        let result = await this.model.onInsertPoll(_this, topicId, categoryId, position, data);
        console.log('result', result);
        this.closeModal();

      } else {
        console.log('poll-ui-builder: insertPoll: no onInsertPoll callback argument is given');
      }
    }

  }

  @action
  toggleAdvanced() {
    this.toggleProperty("showAdvanced");
    if (this.showAdvanced) {
      this.set(
        "pollOptionsText",
        this.pollOptions.map((x) => x.value).join("\n")
      );

      // 자동으로 안되서 강제 설정
      setTimeout(() => {
        this._restorePollScoreOptionSelection();
      }, 150);
    }
  }

  @action
  updateValue(option, event) {
    option.set("value", event.target.value);
  }

  @action
  updateUrlValue(dataLink, event) {
    dataLink.set("url", event.target.value);
  }

  @action
  updateTitleValue(dataLink, event) {
    dataLink.set("title", event.target.value);
  }

  @action
  updateContentValue(dataLink, event) {
    dataLink.set("content", event.target.value);
  }

  @action
  onInputKeydown(index, event) {
    if (event.key === "Enter") {
      event.preventDefault();
      event.stopPropagation();

      if (event.target.value !== "") {
        this.addOption(index + 1);
      }
    }
  }

  @action
  addOption(atIndex) {
    if (atIndex === -1) {
      atIndex = this.pollOptions.length;
    }

    const option = EmberObject.create({ value: "" });
    this.pollOptions.insertAt(atIndex, option);
  }

  @action
  removeOption(option) {
    this.pollOptions.removeObject(option);
  }

  @action
  addDataLinkOption(atIndex) {
    if (atIndex === -1) {
      atIndex = this.pollDataLinks.length;
    }

    const dataLink = EmberObject.create({ url: "", title: "", content: ""});
    this.pollDataLinks.insertAt(atIndex, dataLink);
  }

  @action
  removeDataLinkOption(option) {
    this.pollDataLinks.removeObject(option);
  }

  @action
  updateOptionCorrect(option, event) {
    if(event.target.checked) {
      option.set("correct", true);
    } else {
      option.set("correct", false);
    }
  }

  @action
  updateScore(event) {
    //event?.preventDefault();
    this.set('score', event.target.value);
  }

  // 자동으로 안되서 강제로 설정
  _restorePollScoreOptionSelection() {
    const el = document.querySelector('#poll-score-select');
    if(el) {
      el.querySelector(`option[value="${this.score}"]`).selected = true;
    }
  }

  @action
  updatePollType(pollType, event) {
    event?.preventDefault();
    this.set("pollType", pollType);
  }

  @action
  togglePublic() {
    this.set("publicPoll", !this.publicPoll);
  }
}
