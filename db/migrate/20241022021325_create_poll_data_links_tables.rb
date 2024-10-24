# frozen_string_literal: true

class CreatePollDataLinksTables < ActiveRecord::Migration[5.2]
  def change
    create_table :poll_data_links do |t|
      t.references :poll, index: true, foreign_key: true
      t.string :link, null: false
      t.string :title, null: false
      t.text :content
      t.timestamps
    end
  end
end
