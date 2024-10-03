import Service from '@ember/service';
import { inject as service } from '@ember/service';
import { computed } from '@ember/object';
import { ajax } from 'discourse/lib/ajax';

export default Service.extend({
  store: service(),
  polls: computed(function() {
    return ajax("/polls/poll_list.json").then((response) => {
      return response;
    });
  })
});
