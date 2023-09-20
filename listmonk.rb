# frozen_string_literal: true

class ListmonkClient
  def initialize
    @emailable_users = {}
  end

  def truncate_subscribers_table
    monkconn.exec('TRUNCATE TABLE subscribers CASCADE')
  end

  def truncate_lists_table
    monkconn.exec('TRUNCATE TABLE lists CASCADE')
  end

  def truncate_subscriber_lists_table
    monkconn.exec('TRUNCATE TABLE subscriber_lists CASCADE')
  end

  def import_subscribers(subscriber_list)
    monkconn.copy_data 'COPY subscribers (email, name, uuid, status, attribs) FROM STDIN', enco do
      subscriber_list.each do |s|
        monkconn.put_copy_data [
          s['email'],
          s['display_name'],
          s['uuid'],
          'enabled',
          { unsubscribe_token: s['unsubscribe_token'] }.to_json
        ]
      end
    end
  end

  def subscribers
    result = monkconn.exec('SELECT id, email FROM subscribers WHERE 1')
    result.entries
  end

  def create_lists(lists)
    monkconn.copy_data 'COPY lists (uuid, name, type, description) FROM STDIN', enco do
      lists.each do |l|
        monkconn.put_copy_data [
          l['uuid'],
          l['name'],
          l['type'],
          l['description']
        ]
      end
    end
  end

  def subscribers_by_id
    return @subscribers_by_id if @subscibers_by_id

    results = monkconn.exec('SELECT email, id FROM subscribers').entries
    @subscribers_by_id = Hash[results.map(&:values).map(&:flatten)]
  end

  def lists_by_id
    return @lists_by_id if @lists_by_id

    results = monkconn.exec('SELECT description, id FROM lists').entries
    @lists_by_id = Hash[results.map(&:values).map(&:flatten)]
  end

  def subscribe_users(subscriptions)
    monkconn.copy_data 'COPY subscriber_lists (subscriber_id, list_id, status) FROM STDIN', enco do
      subscriptions.each do |list, users|
        users.each do |u|
          monkconn.put_copy_data [
            @subscribers_by_id[u['email']],
            @lists_by_id[list],
            'confirmed'
          ]
        end
      end
    end
  end

  def monkconn
    @monkconn ||= PG.connect(ENV.fetch('LISTMONK_DB_URI'))
  end

  def enco
    PG::TextEncoder::CopyRow.new
  end

  def find_id_by_desc(desc)
    lists_by_id.find { |l| l['description'] == desc }['id']
  end

  def find_id_by_email(email)
    subscribers_by_id.find { |s| s['email'] == email }['id']
  end
end
