# frozen_string_literal: true

class CreatePollDataLinks < ActiveRecord::Migration[7.0]
  def change
    create_table :poll_data_links do |t|
      t.references :poll, index: true, foreign_key: true
      t.string :title, null: false
      t.string :url
      t.text :content
      t.timestamps
    end
  end
end
