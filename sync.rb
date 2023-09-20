#!/usr/bin/env ruby
# frozen_string_literal: true

require './panoptes'
require './listmonk'

panoptes = PanoptesClient.new
listmonk = ListmonkClient.new

puts 'Building lists...'
panoptes.build_lists
panoptes.split_beta_lists
panoptes.project_emailable_users

puts 'Building subscribers...'
subscribers = panoptes.subscribers

puts 'Truncating Listmonk tables...'
listmonk.truncate_subscribers_table
listmonk.truncate_lists_table
listmonk.truncate_subscriber_lists_table

puts 'Importing subscribers...'
listmonk.import_subscribers(subscribers)

puts 'Creating new lists...'
listmonk.create_lists(panoptes.general_lists)
listmonk.create_lists(panoptes.project_lists)
listmonk.create_lists(panoptes.beta_lists)

puts 'Building ID codexes...'
listmonk.subscribers_by_id
listmonk.lists_by_id

# Subscribe NASA and global, exclude whole beta
puts 'Subscribing general lists...'
listmonk.subscribe_users(panoptes.list_emailable_users.except('beta_email_communication'))

# Subscribe only 3 beta sublists
puts 'Subscribing beta lists...'
listmonk.subscribe_users({ 'beta_list_1' => panoptes.split_beta_lists['beta_list_1'] })
listmonk.subscribe_users({ 'beta_list_2' => panoptes.split_beta_lists['beta_list_2'] })
listmonk.subscribe_users({ 'beta_list_3' => panoptes.split_beta_lists['beta_list_3'] })

puts 'Subscribing project lists...'
grouped_by_project = panoptes.project_emailable_users.group_by { |h| h['slug'] }
listmonk.subscribe_users(grouped_by_project)

puts 'Finished! Listmonk email sync complete.'
