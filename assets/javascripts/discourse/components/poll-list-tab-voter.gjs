import Component from "@glimmer/component";
import i18n from "discourse-common/helpers/i18n";

export default class PollListTabVoterComponent extends Component {
  get voters() {
    var voters=[];

    this.args.options.forEach((option) => {
      if(option.votes>0) {
        this.args.preloaded_voters[option.id].forEach((voter) => {
          voter.avatar_template=voter.avatar_template.replace('{size}',32);
          voters.push(voter);
       });
      }
    });

    return voters.slice(0, 5);
  }

  <template>
    <div class="voter-list">
      <ul>
          {{#each this.voters as |voter|}}
          <li>
            <img src="{{voter.avatar_template}}">&nbsp;&nbsp;{{voter.username}}
          </li>
          {{/each}}
      </ul>
    </div>
  </template>
}
