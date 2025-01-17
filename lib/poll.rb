# frozen_string_literal: true

class DiscoursePoll::Poll
  RANKED_CHOICE = "ranked_choice"
  MULTIPLE = "multiple"
  REGULAR = "regular"

  def self.vote(user, post_id, poll_name, options)
    poll_id = nil

    serialized_poll =
      DiscoursePoll::Poll.change_vote(user, post_id, poll_name) do |poll|
        poll_id = poll.id
        # remove options that aren't available in the poll
        available_options = poll.poll_options.map { |o| o.digest }.to_set

        if poll.ranked_choice?
          options = options.values.map { |hash| hash }
          options.select! { |o| available_options.include?(o[:digest]) }
        else
          options.select! { |o| available_options.include?(o) }
        end

        if options.empty?
          raise DiscoursePoll::Error.new I18n.t("poll.requires_at_least_1_valid_option")
        end

        new_option_ids =
          poll
            .poll_options
            .each_with_object([]) do |option, obj|
              if poll.ranked_choice?
                obj << option.id if options.any? { |o| o[:digest] == option.digest }
              else
                obj << option.id if options.include?(option.digest)
              end
            end

        self.validate_votes!(poll, new_option_ids)

        old_option_ids =
          poll
            .poll_options
            .each_with_object([]) do |option, obj|
              obj << option.id if option.poll_votes.where(user_id: user.id).exists?
            end

        if poll.ranked_choice?
          # for ranked choice, we need to remove all votes and re-create them as there is no way to update them due to lack of primary key.
          PollVote.where(poll: poll, user: user).delete_all
          creation_set = new_option_ids
        else
          # remove non-selected votes
          PollVote
            .where(poll: poll, user: user)
            .where.not(poll_option_id: new_option_ids)
            .delete_all
          creation_set = new_option_ids - old_option_ids
        end

        # create missing votes
        creation_set.each do |option_id|
          if poll.ranked_choice?
            option_digest = poll.poll_options.find(option_id).digest

            PollVote.create!(
              poll: poll,
              user: user,
              poll_option_id: option_id,
              rank: options.find { |o| o[:digest] == option_digest }[:rank],
            )
          else
            PollVote.create!(poll: poll, user: user, poll_option_id: option_id)
          end
        end
      end

    if serialized_poll[:type] == RANKED_CHOICE
      serialized_poll[:ranked_choice_outcome] = DiscoursePoll::RankedChoice.outcome(poll_id)
    else
      # Ensure consistency here as we do not have a unique index to limit the
      # number of votes per the poll's configuration.
      is_multiple = serialized_poll[:type] == MULTIPLE
      offset = is_multiple ? (serialized_poll[:max] || serialized_poll[:options].length) : 1

      params = { poll_id: poll_id, offset: offset, user_id: user.id }

      DB.query(<<~SQL, params)
      DELETE FROM poll_votes
      USING (
        SELECT
          poll_id,
          user_id
        FROM poll_votes
        WHERE poll_id = :poll_id
        AND user_id = :user_id
        ORDER BY created_at DESC
        OFFSET :offset
      ) to_delete_poll_votes
      WHERE poll_votes.poll_id = to_delete_poll_votes.poll_id
      AND poll_votes.user_id = to_delete_poll_votes.user_id
      SQL
    end

    serialized_poll[:options].each do |option|
      if serialized_poll[:type] == RANKED_CHOICE
        option.merge!(
          rank:
            PollVote
              .joins(:poll_option)
              .where(poll_options: { digest: option[:id] }, user_id: user.id, poll_id: poll_id)
              .limit(1)
              .pluck(:rank),
        )
      elsif serialized_poll[:type] == MULTIPLE
        option.merge!(
          chosen:
            PollVote
              .joins(:poll_option)
              .where(poll_options: { digest: option[:id] }, user_id: user.id, poll_id: poll_id)
              .exists?,
        )
      end
    end

    if serialized_poll[:type] == MULTIPLE
      serialized_poll[:options].each do |option|
        option.merge!(
          chosen:
            PollVote
              .joins(:poll_option)
              .where(poll_options: { digest: option[:id] }, user_id: user.id, poll_id: poll_id)
              .exists?,
        )
      end
    end

    [serialized_poll, options]
  end

  def self.remove_vote(user, post_id, poll_name)
    poll_id = nil

    serialized_poll =
      DiscoursePoll::Poll.change_vote(user, post_id, poll_name) do |poll|
        poll_id = poll.id
        PollVote.where(poll: poll, user: user).delete_all
      end

    if serialized_poll[:type] == RANKED_CHOICE
      serialized_poll[:ranked_choice_outcome] = DiscoursePoll::RankedChoice.outcome(poll_id)
    end

    serialized_poll
  end

  def self.toggle_status(user, post_id, poll_name, status, raise_errors = true)
    Poll.transaction do
      post = Post.find_by(id: post_id)
      guardian = Guardian.new(user)

      # post must not be deleted
      if post.nil? || post.trashed?
        raise DiscoursePoll::Error.new I18n.t("poll.post_is_deleted") if raise_errors
        return
      end

      # topic must not be archived
      if post.topic&.archived
        if raise_errors
          raise DiscoursePoll::Error.new I18n.t("poll.topic_must_be_open_to_toggle_status")
        end
        return
      end

      # either staff member or OP
      unless post.user_id == user&.id || user&.staff?
        if raise_errors
          raise DiscoursePoll::Error.new I18n.t("poll.only_staff_or_op_can_toggle_status")
        end
        return
      end

      poll = Poll.find_by(post_id: post_id, name: poll_name)

      if !poll
        if raise_errors
          raise DiscoursePoll::Error.new I18n.t("poll.no_poll_with_this_name", name: poll_name)
        end
        return
      end

      poll.status = status
      poll.save!

      serialized_poll = PollSerializer.new(poll, root: false, scope: guardian).as_json
      payload = { post_id: post_id, polls: [serialized_poll] }

      post.publish_message!("/polls/#{post.topic_id}", payload)

      serialized_poll
    end
  end

  def self.serialized_voters(poll, opts = {})
    limit = (opts["limit"] || 25).to_i
    limit = 0 if limit < 0
    limit = 50 if limit > 50

    page = (opts["page"] || 1).to_i
    page = 1 if page < 1

    offset = (page - 1) * limit

    option_digest = opts["option_id"].to_s

    if poll.number?
      user_ids =
        PollVote
          .where(poll: poll)
          .group(:user_id)
          .order("MIN(created_at)")
          .offset(offset)
          .limit(limit)
          .pluck(:user_id)

      result = User.where(id: user_ids).map { |u| UserNameSerializer.new(u).serializable_hash }
    elsif option_digest.present?
      poll_option = PollOption.find_by(poll: poll, digest: option_digest)

      raise Discourse::InvalidParameters.new(:option_id) unless poll_option

      if poll.ranked_choice?
        params = {
          poll_id: poll.id,
          option_digest: option_digest,
          offset: offset,
          offset_plus_limit: offset + limit,
        }

        votes = DB.query(<<~SQL, params)
        SELECT digest, rank, user_id
          FROM (
            SELECT digest
                  , CASE rank WHEN 0 THEN 'Abstain' ELSE CAST(rank AS text) END AS rank
                  , user_id
                  , username
                  , ROW_NUMBER() OVER (PARTITION BY poll_option_id ORDER BY pv.created_at) AS row
              FROM poll_votes pv
              JOIN poll_options po ON pv.poll_option_id = po.id
              JOIN users u ON pv.user_id = u.id
              WHERE pv.poll_id = :poll_id
                AND po.poll_id = :poll_id
                AND po.digest = :option_digest
          ) v
          WHERE row BETWEEN :offset AND :offset_plus_limit
          ORDER BY digest, CASE WHEN rank = 'Abstain' THEN 1 ELSE CAST(rank AS integer) END, username
        SQL

        user_ids = votes.map(&:user_id).uniq

        user_hashes =
          User
            .where(id: user_ids)
            .map { |u| [u.id, UserNameSerializer.new(u).serializable_hash] }
            .to_h

        ranked_choice_users = []
        votes.each do |v|
          ranked_choice_users ||= []
          ranked_choice_users << { rank: v.rank, user: user_hashes[v.user_id] }
        end
        user_hashes = ranked_choice_users
      else
        user_ids =
          PollVote
            .where(poll: poll, poll_option: poll_option)
            .group(:user_id)
            .order("MIN(created_at)")
            .offset(offset)
            .limit(limit)
            .pluck(:user_id)

        user_hashes =
          User.where(id: user_ids).map { |u| UserNameSerializer.new(u).serializable_hash }
      end
      result = { option_digest => user_hashes }
    else
      params = { poll_id: poll.id, offset: offset, offset_plus_limit: offset + limit }
      if poll.ranked_choice?
        votes = DB.query(<<~SQL, params)
        SELECT digest, rank, user_id
          FROM (
            SELECT digest
                  , CASE rank WHEN 0 THEN 'Abstain' ELSE CAST(rank AS text) END AS rank
                  , user_id
                  , username
                  , ROW_NUMBER() OVER (PARTITION BY poll_option_id ORDER BY pv.created_at) AS row
              FROM poll_votes pv
              JOIN poll_options po ON pv.poll_option_id = po.id
              JOIN users u ON pv.user_id = u.id
              WHERE pv.poll_id = :poll_id
                AND po.poll_id = :poll_id
          ) v
          WHERE row BETWEEN :offset AND :offset_plus_limit
          ORDER BY digest, CASE WHEN rank = 'Abstain' THEN 1 ELSE CAST(rank AS integer) END, username
        SQL
      else
        votes = DB.query(<<~SQL, params)
          SELECT digest, user_id
            FROM (
              SELECT digest
                    , user_id
                    , ROW_NUMBER() OVER (PARTITION BY poll_option_id ORDER BY pv.created_at) AS row
                FROM poll_votes pv
                JOIN poll_options po ON pv.poll_option_id = po.id
                WHERE pv.poll_id = :poll_id
                  AND po.poll_id = :poll_id
            ) v
            WHERE row BETWEEN :offset AND :offset_plus_limit
        SQL
      end

      user_ids = votes.map(&:user_id).uniq

      user_hashes =
        User
          .where(id: user_ids)
          .map { |u| [u.id, UserNameSerializer.new(u).serializable_hash] }
          .to_h

      result = {}
      votes.each do |v|
        if poll.ranked_choice?
          result[v.digest] ||= []
          result[v.digest] << { rank: v.rank, user: user_hashes[v.user_id] }
        else
          result[v.digest] ||= []
          result[v.digest] << user_hashes[v.user_id]
        end
      end
    end

    result
  end

  def self.transform_for_user_field_override(custom_user_field)
    existing_field = UserField.find_by(name: custom_user_field)
    existing_field ? "user_field_#{existing_field.id}" : custom_user_field
  end

  def self.grouped_poll_results(user, post_id, poll_name, user_field_name)
    raise Discourse::InvalidParameters.new(:post_id) if !Post.where(id: post_id).exists?
    poll =
      Poll.includes(:poll_options, :poll_votes, post: :topic).find_by(
        post_id: post_id,
        name: poll_name,
      )
    raise Discourse::InvalidParameters.new(:poll_name) unless poll

    # user must be allowed to post in topic
    guardian = Guardian.new(user)
    if !guardian.can_create_post?(poll.post.topic)
      raise DiscoursePoll::Error.new I18n.t("poll.user_cant_post_in_topic")
    end

    if SiteSetting.poll_groupable_user_fields.split("|").exclude?(user_field_name)
      raise Discourse::InvalidParameters.new(:user_field_name)
    end

    poll_votes = poll.poll_votes

    poll_options = {}
    poll.poll_options.each do |option|
      poll_options[option.id.to_s] = { html: option.html, digest: option.digest }
    end

    user_ids = poll_votes.map(&:user_id).uniq
    user_fields =
      UserCustomField.where(
        user_id: user_ids,
        name: transform_for_user_field_override(user_field_name),
      )

    user_field_map = {}
    user_fields.each do |f|
      # Build hash, so we can quickly look up field values for each user.
      user_field_map[f.user_id] = f.value
    end

    votes_with_field =
      poll_votes.map do |vote|
        v = vote.attributes
        v[:field_value] = user_field_map[vote.user_id]
        v
      end

    chart_data = []
    votes_with_field
      .group_by { |vote| vote[:field_value] }
      .each do |field_answer, votes|
        grouped_selected_options = {}

        # Create all the options with 0 votes. This ensures all the charts will have the same order of options, and same colors per option.
        poll_options.each do |id, option|
          grouped_selected_options[id] = { digest: option[:digest], html: option[:html], votes: 0 }
        end

        # Now go back and update the vote counts. Using hashes so we dont have n^2
        votes
          .group_by { |v| v["poll_option_id"] }
          .each do |option_id, votes_for_option|
            grouped_selected_options[option_id.to_s][:votes] = votes_for_option.length
          end

        group_label = field_answer ? field_answer.titleize : I18n.t("poll.user_field.no_data")
        chart_data << { group: group_label, options: grouped_selected_options.values }
      end
    chart_data
  end

  def self.schedule_jobs(post)
    Poll
      .where(post: post)
      .find_each do |poll|
        job_args = { post_id: post.id, poll_name: poll.name }

        Jobs.cancel_scheduled_job(:close_poll, job_args)

        if poll.open? && poll.close_at && poll.close_at > Time.zone.now
          Jobs.enqueue_at(poll.close_at, :close_poll, job_args)
        end
      end
  end

  def self.create!(post_id, poll)
    close_at =
      begin
        Time.zone.parse(poll["close"] || "")
      rescue ArgumentError
      end

    created_poll =
      Poll.create!(
        post_id: post_id,
        name: poll["name"].presence || "poll",
        close_at: close_at,
        type: poll["type"].presence || REGULAR,
        status: poll["status"].presence || "open",
        visibility: poll["public"] == "true" ? "everyone" : "secret",
        title: poll["title"],
        results: poll["results"].presence || "always",
        min: poll["min"],
        max: poll["max"],
        step: poll["step"],
        chart_type: poll["charttype"] || "bar",
        score:  poll["score"],
        groups: poll["groups"],
      )

    poll["options"].each do |option|
      PollOption.create!(
        poll: created_poll,
        correct: option["correct"],
        digest: option["id"].presence,
        html: option["html"].presence&.strip,
      )
    end
  end

  def self.extract(raw, topic_id, user_id = nil)
    # Poll Post handlers get called very early in the post
    # creation process. `raw` could be nil here.
    return [] if raw.blank?

    # bail-out early if the post does not contain a poll
    return [] if !raw.include?("[/poll]")

    # TODO: we should fix the callback mess so that the cooked version is available
    # in the validators instead of cooking twice
    raw = raw.sub(%r{\[quote.+/quote\]}m, "")
    cooked = PrettyText.cook(raw, topic_id: topic_id, user_id: user_id)

    pp "#raw######################"
    pp raw
    pp "#cooked######################"
    pp cooked
    pp "#######################"

    Nokogiri
      .HTML5(cooked)
      .css("div.poll")
      .map do |p|
        poll = { "options" => [], "name" => DiscoursePoll::DEFAULT_POLL_NAME, "data_links" => [] }

        # attributes
        p.attributes.values.each do |attribute|
          if attribute.name.start_with?(DiscoursePoll::DATA_PREFIX)
            poll[attribute.name[DiscoursePoll::DATA_PREFIX.length..-1]] = CGI.escapeHTML(
              attribute.value || "",
            )
          end
        end

        # options
        p
          .css("li[#{DiscoursePoll::DATA_PREFIX}option-id]")
          .each do |o|
            option_id = o.attributes[DiscoursePoll::DATA_PREFIX + "option-id"].value.to_s
            html=o.inner_html.strip.to_s

            correct=false
            if html.include?"[correct]"
              html=html.sub("[correct]", "")
              correct=true
            end
            poll["options"] << { "id" => option_id, "html" => html, "correct"=>correct }
          end

        # title
        title_element = p.css(".poll-title").first
        poll["title"] = title_element.inner_html.strip if title_element

        # added by etna
        # TODO: poll 여러 개일 경우 수정 반영할 것.
        Nokogiri
          .HTML5(cooked)
          .css("div.poll-data-link")
          .each do |d|
            link = d.css('a').first
            url = ""
            title = ""
            if link.present?
              # url = link.attributes.to_s
              # pp "U################## url #{url}"
              url = link.attributes['href']&.value.to_s || ""
              title = link.text || ""
            end

            content = d.to_s.gsub(/<a.*<\/a><br>/, '') # 링크 제거
            new_data_link = { "title" => title.strip, "url" => url.strip, "content" => Nokogiri::HTML(content).text.strip }
            next if poll["data_links"].filter { |x| x == new_data_link }.present? # 중복된것 있으면 무시

            data_links_updated = false
            poll["data_links"] = poll["data_links"].map do |x|
              if x['url'] == new_data_link['url']
                x['title'] = new_data_link['title']
                x['url'] = new_data_link['url']
                x['content'] = new_data_link['content']
                data_links_updated = true
              end
              x
            end
            next if data_links_updated

            poll["data_links"] << new_data_link
          end

          #pp "################## pol: #{poll.to_s}"

        poll
      end
  end

  def self.validate_votes!(poll, options)
    num_of_options = options.length

    if poll.multiple?
      if poll.min && (num_of_options < poll.min)
        raise DiscoursePoll::Error.new(I18n.t("poll.min_vote_per_user", count: poll.min))
      elsif poll.max && (num_of_options > poll.max)
        raise DiscoursePoll::Error.new(I18n.t("poll.max_vote_per_user", count: poll.max))
      end
    elsif poll.ranked_choice?
      if poll.poll_options.length != num_of_options
        raise DiscoursePoll::Error.new(
                I18n.t(
                  "poll.ranked_choice.vote_options_mismatch",
                  count: poll.options.length,
                  provided: num_of_options,
                ),
              )
      end
    elsif num_of_options > 1
      raise DiscoursePoll::Error.new(I18n.t("poll.one_vote_per_user"))
    end
  end
  private_class_method :validate_votes!

  def self.change_vote(user, post_id, poll_name)
    Poll.transaction do
      post = Post.find_by(id: post_id)

      # post must not be deleted
      raise DiscoursePoll::Error.new I18n.t("poll.post_is_deleted") if post.nil? || post.trashed?

      # topic must not be archived
      if post.topic&.archived
        raise DiscoursePoll::Error.new I18n.t("poll.topic_must_be_open_to_vote")
      end

      # user must be allowed to post in topic
      guardian = Guardian.new(user)
      if !guardian.can_create_post?(post.topic)
        raise DiscoursePoll::Error.new I18n.t("poll.user_cant_post_in_topic")
      end

      poll = Poll.includes(:poll_options).find_by(post_id: post_id, name: poll_name)

      unless poll
        raise DiscoursePoll::Error.new I18n.t("poll.no_poll_with_this_name", name: poll_name)
      end
      raise DiscoursePoll::Error.new I18n.t("poll.poll_must_be_open_to_vote") if poll.is_closed?

      if poll.groups
        poll_groups = poll.groups.split(",").map(&:downcase)
        user_groups = user.groups.map { |g| g.name.downcase }
        if (poll_groups & user_groups).empty?
          raise DiscoursePoll::Error.new I18n.t("js.poll.results.groups.title", groups: poll.groups)
        end
      end

      yield(poll)

      poll.reload

      serialized_poll = PollSerializer.new(poll, root: false, scope: guardian).as_json
      payload = { post_id: post_id, polls: [serialized_poll] }

      post.publish_message!("/polls/#{post.topic_id}", payload)

      serialized_poll
    end
  end
end
