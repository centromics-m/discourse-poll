# frozen_string_literal: true

class DiscoursePoll::PollsController < ::ApplicationController
  requires_plugin DiscoursePoll::PLUGIN_NAME

  before_action :ensure_logged_in, except: %i[voters poll_list grouped_poll_results]

  def poll_list
    if params[:category].present?
      category = params[:category]
    else
      category = 4
    end

    # find only in non-deleted topics and same category
    @polls = Poll.joins(:post).joins('INNER JOIN topics AS t ON posts.topic_id = t.id')
      .where('t.category_id': category, 't.deleted_at': nil).order('id desc').limit(10)

    render json: @polls, each_serializer: PollSerializer
  end

  def poll_admin_list
    page = params[:page] || 1
    pagesize =  10

    page1 = (page.to_i - 1).to_i
    pagesize1 = pagesize.to_i

    query = Poll.order('id desc')
    total = query.clone.count
    @polls = query.limit(pagesize1).offset(page1 * pagesize1)

    total_pages = (total.to_f / pagesize).ceil

    render json: { poll_list: {polls:serialize_data( @polls, PollSerializer), total_pages: total_pages, total:total } }
  end

  def vote
    post_id = params.require(:post_id)
    poll_name = params.require(:poll_name)
    options = params.require(:options)

    begin
      poll, options = DiscoursePoll::Poll.vote(current_user, post_id, poll_name, options)
      render json: { poll: poll, vote: options }
    rescue DiscoursePoll::Error => e
      render_json_error e.message
    end
  end

  def remove_vote
    post_id = params.require(:post_id)
    poll_name = params.require(:poll_name)

    begin
      poll = DiscoursePoll::Poll.remove_vote(current_user, post_id, poll_name)
      render json: { poll: poll }
    rescue DiscoursePoll::Error => e
      render_json_error e.message
    end
  end

  def toggle_status
    post_id = params.require(:post_id)
    poll_name = params.require(:poll_name)
    status = params.require(:status)

    begin
      poll = DiscoursePoll::Poll.toggle_status(current_user, post_id, poll_name, status)
      render json: { poll: poll }
    rescue DiscoursePoll::Error => e
      render_json_error e.message
    end
  end

  def voters
    post_id = params.require(:post_id)
    poll_name = params.require(:poll_name)
    opts = params.permit(:limit, :page, :option_id)

    raise Discourse::InvalidParameters.new(:post_id) if !Post.where(id: post_id).exists?

    poll = Poll.find_by(post_id: post_id, name: poll_name)
    raise Discourse::InvalidParameters.new(:poll_name) if !poll&.can_see_voters?(current_user)

    render json: { voters: DiscoursePoll::Poll.serialized_voters(poll, opts) }
  end

  def grouped_poll_results
    post_id = params.require(:post_id)
    poll_name = params.require(:poll_name)
    user_field_name = params.require(:user_field_name)

    poll = Poll.find_by(post_id: post_id, name: poll_name)

    if poll.nil?
      render json: { error: I18n.t("poll.errors.poll_not_found") }, status: :not_found
    elsif poll.ranked_choice?
      render json: {
               error: I18n.t("poll.ranked_choice.no_group_results_support"),
             },
             status: :unprocessable_entity
    else
      begin
        render json: {
                 grouped_results:
                   DiscoursePoll::Poll.grouped_poll_results(
                     current_user,
                     post_id,
                     poll_name,
                     user_field_name,
                   ),
               }
      rescue DiscoursePoll::Error => e
        render_json_error e.message
      end
    end
  end
end
