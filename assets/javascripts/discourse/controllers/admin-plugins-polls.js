import Controller from '@ember/controller';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';
import { tracked } from '@glimmer/tracking';
import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import { computed } from '@ember/object';
import I18n from 'I18n';

export default class AdminPluginsPollsController extends Controller {
  @service modal;
  @service dialog;
  @service toasts;
  @tracked creatingNew = false;
  @tracked polls = [];
  currentPage =1;
  totalPages = null;
  total = 0

  @computed('model.polls.@each.updatedAt')
  get sortedPolls() {
    return this.model.polls?.sortBy('updatedAt').reverse() || [];
  }

  formatDate(date) {
    if(date) {
      return moment(date).format("YYYY-MM-DD");
    }
  }

  @action
  createNew() {
    this.creatingNew = true;
    this.modal.show('admin-plugins-polls-new');
  }

  getNumber(total,currentPage, index) {
    return total-((currentPage-1)*10)-index;
  }

  @action
  async loadPage(page) {
    if (page === this.currentPage) return;

    this.set("isLoading", true);

    try {
      // AJAX 요청으로 특정 페이지 데이터 가져오기
      const response = await ajax(`/polls/poll_admin_list.json?page=${page}`);
      const { polls, total_pages, total } = response;
      this.setProperties({
        polls,
        currentPage: page,
        totalPages: total_pages,
        total: total
      });
    } catch (e) {
      console.error("Failed to load page:", e);
    } finally {
      this.set("isLoading", false);
    }
  }

  @action
   destroyPoll(poll) {
   this.dialog.deleteConfirm({
      message: I18n.t('poll.admin.confirm_destroy'),
       didConfirm: () => {
         let poll_id=poll.id;
         return ajax(`/polls/remove-poll/${poll.id}.json`, { type: 'DELETE', }).then((response) => {
         this.toasts.success({
            duration: 3000,
           data: { message: I18n.t('poll.admin.delete_success') },
         });
           this.polls = this.polls.filter(poll => poll.id !== poll_id);// Array에서 poll 제거
         }).catch(popupAjaxError);
      },
     });
  }

  get paginationRange() {
    const range = [];
    const totalPages = this.totalPages || 1;

    for (let i = 1; i <= totalPages; i++) {
      range.push(i);
    }
    return range;
  }
}
