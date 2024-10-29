import Service from '@ember/service';
import { tracked } from '@glimmer/tracking';
import { inject as service } from '@ember/service';
import { computed } from '@ember/object';
import { ajax } from 'discourse/lib/ajax';

export default class pollsService extends Service {
  @tracked category=4;

  setCategory(category) {
    this.set('category',category)
  }

  get polls() {
    return ajax("/polls/poll_list.json?category="+this.category).then((response) => {
      return response;
    });
  }
}
