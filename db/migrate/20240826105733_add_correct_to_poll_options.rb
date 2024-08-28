# frozen_string_literal: true

class AddCorrectToPollOptions < ActiveRecord::Migration[7.0]
  def change
    add_column :poll_options, :correct, :boolean, null: false, default: 0
  end
end
