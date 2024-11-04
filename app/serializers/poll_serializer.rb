# frozen_string_literal: true

class PollSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :type,
             :status,
             :public,
             :results,
             :min,
             :max,
             :step,
             :options,
             :voters,
             :close,
             :preloaded_voters,
             :chart_type,
             :groups,
             :title,
             :score,
             :ranked_choice_outcome,
             :post_id,
             :post_url,
             :post_topic_title,
             :post_topic_poll,
             :post_topic_overview,
             :poll_data_link,
             :created_at,
             :updated_at

  def public
    true
  end

  def score
    object.score
  end

  def include_public?
    object.everyone?
  end

  def include_min?
    object.min.present? && (object.number? || object.multiple?)
  end

  def include_max?
    object.max.present? && (object.number? || object.multiple?)
  end

  def include_step?
    object.step.present? && object.number?
  end

  def include_groups?
    groups.present?
  end

  def options
    can_see_results = object.can_see_results?(scope.user)

    object.poll_options.map do |option|
      PollOptionSerializer.new(
        option,
        root: false,
        scope: {
          can_see_results: can_see_results,
        },
      ).as_json
    end
  end

  def voters
    object.poll_votes.count("DISTINCT user_id") + object.anonymous_voters.to_i
  end

  def close
    object.close_at
  end

  def include_close?
    object.close_at.present?
  end

  def preloaded_voters
    DiscoursePoll::Poll.serialized_voters(object)
  end

  def include_preloaded_voters?
    object.can_see_voters?(scope.user)
  end

  def include_ranked_choice_outcome?
    object.ranked_choice?
  end

  def ranked_choice_outcome
    DiscoursePoll::RankedChoice.outcome(object.id)
  end

  def post_url
    object.post.url
  end

  def post_topic_title
    object.post&.topic&.title
  end

  def post_topic_poll
    html_string = object.post&.cooked
    doc = Nokogiri::HTML(html_string)
    doc_element = doc.css('.poll')

    return doc_element.to_html
  end

  def poll_data_link
    html_string = object.post&.cooked
    doc = Nokogiri::HTML(html_string)
    doc_element = doc.css('.poll-data-link')

    return doc_element.to_html
  end

  def post_topic_overview
    html_string = object.post&.cooked
    doc = Nokogiri::HTML(html_string)
    doc.css('.poll').each(&:remove)
    doc.css('.poll-data-link').each(&:remove)

    return doc.to_html
  end
end
