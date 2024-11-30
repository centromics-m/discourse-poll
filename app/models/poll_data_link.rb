# frozen_string_literal: true

class PollDataLink < ActiveRecord::Base
  belongs_to :poll
end

# == Schema Information
#
# Table name: poll_options
#
#  id              :bigint           not null, primary key
#  poll_id         :bigint
#  title          :string            not null
#  url            :string
#  content        :text
