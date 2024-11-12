# frozen_string_literal: true

class AddScoreToPolls < ActiveRecord::Migration[7.0]
  def change
    add_column :polls, :score, :integer #, null: false, default: 100
  end
end
