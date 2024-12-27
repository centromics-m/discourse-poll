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
             :poll_data_links,
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

    doc_element.to_html
  end

  # NOTE: poll.rb#self.extract 참고
  def poll_data_links
    html_string = object.post&.cooked
    doc = Nokogiri::HTML(html_string)

    data_links = []

    doc.css('.poll-data-link').each do |d|
      link = d.css('a').first
      url = ""
      title = ""
      if link.present?
        url = link.attributes['href']&.value.to_s || ""
        title = link.text || ""
      end

      content = d.to_s.gsub(/<a.*<\/a><br>/, '')
      new_data_link = { "title" => title.strip, "url" => url.strip, "content" => Nokogiri::HTML(content).text.strip }
      next if data_links.filter { |x| x == new_data_link }.present? # 중복된것 있으면 무시

      data_links_updated = false
      data_links = data_links.map do |x|
        if x['url'] == new_data_link['url']
          x['title'] = new_data_link['title']
          x['url'] = new_data_link['url']
          x['content'] = new_data_link['content']
          data_links_updated = true
        end
        x
      end
      next if data_links_updated

      data_links << new_data_link
    end

    # pp "################ poll_data_links html_string: #{html_string}"
    # pp "################ poll_data_links: #{data_links}"

    data_links
  end

  def post_topic_overview
    html_string = object.post&.cooked
    doc = Nokogiri::HTML(html_string)
    doc.css('.poll').each(&:remove)
    doc.css('.poll-data-link').each(&:remove)

    doc.to_html
  end
end
