# frozen_string_literal: true

class PollOptionSerializer < ApplicationSerializer
  attributes :id, :correct, :html, :votes

  def id
    object.digest
  end

  def votes
    # `size` instead of `count` to prevent N+1
    object.poll_votes.size + object.anonymous_votes.to_i
  end

  def include_votes?
    scope[:can_see_results]
  end
end
