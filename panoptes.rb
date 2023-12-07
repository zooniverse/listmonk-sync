# frozen_string_literal: true

require 'pg'
require 'securerandom'

class PanoptesClient
  attr_reader :list_emailable_users

  EXPORT_FIELDS = [
    'global_email_communication',
    'beta_email_communication',
    'nasa_email_communication'
  ].freeze

  def initialize
    @list_emailable_users = {}
  end

  def build_lists
    EXPORT_FIELDS.each do |export_type|
      build_list_by_type(export_type)
    end
  end

  def build_list_by_type(export_type)
    return 'List already built' if @list_emailable_users[export_type]

    @list_emailable_users[export_type] ||= conn.exec(
      "SELECT
        users.email,
        users.display_name,
        users.unsubscribe_token
      FROM
      	users
      WHERE
      	users.activated_state = 0
      	AND users.valid_email = TRUE
      	AND users.#{export_type} = TRUE"
    ).entries
  end

  def delisted
    return @delisted if @delisted
    return 'Lists not built' if @list_emailable_users.empty?

    @delisted = []
    EXPORT_FIELDS.each do |export_type|
      @delisted << @list_emailable_users[export_type]
    end
    @delisted.flatten!
  end

  def project_emailable_users
    @project_emailable_users ||= conn.exec(
      "SELECT
      	users.email,
        users.display_name,
      	users.unsubscribe_token,
      	user_project_preferences.project_id,
      	projects.slug,
        projects.display_name AS project_display_name
      FROM
      	users
      	INNER JOIN user_project_preferences ON user_project_preferences.user_id = users.id
      	LEFT JOIN projects ON projects.id = user_project_preferences.project_id
      WHERE
      	user_project_preferences.email_communication = TRUE
      	AND users.activated_state = 0
      	AND users.valid_email = TRUE
        AND projects.launch_approved = TRUE"
    ).entries
  end

  # Strip project info to do better deduping
  def deprojected
    @deprojected ||= project_emailable_users.map do |h|
      {
        'email' => h['email'],
        'display_name' => h['display_name'],
        'unsubscribe_token' => h['unsubscribe_token']
      }
    end
  end

  def subscribers
    return @subscribers if @subscribers

    @subscribers = (delisted.uniq + deprojected.uniq).uniq
    @subscribers.map { |s| s['uuid'] = SecureRandom.uuid }
    @subscribers
  end

  def general_lists
    # Don't create the beta list, that gets broken up later
    @general_lists ||= %w[global_email_communication nasa_email_communication].map(&:to_s).map do |list_name|
      {
        'uuid' => SecureRandom.uuid,
        'name' => list_name,
        'type' => 'private',
        'description' => list_name
      }
    end
  end

  def beta_lists
    @beta_lists ||= %w[beta_list_1 beta_list_2 beta_list_3].map do |list_name|
      {
        'uuid' => SecureRandom.uuid,
        'name' => list_name,
        'type' => 'private',
        'description' => list_name
      }
    end
  end

  def shuffled_beta_list
    @shuffled_beta_list ||= list_emailable_users['beta_email_communication'].shuffle
  end

  def split_beta_lists
    return @split_beta_lists if @split_beta_lists

    @split_beta_lists = {}
    shuffled_beta_list.each_slice(75000).with_index do |a, i|
      @split_beta_lists["beta_list_#{i}"] = a
    end
    @split_beta_lists
  end

  def project_lists
    @project_lists ||= project_emailable_users.uniq { |list| list['slug'] }.map do |h|
      {
        'uuid' => SecureRandom.uuid,
        'name' => h['project_display_name'],
        'type' => 'private',
        'description' => h['slug']
      }
    end
  end

  private

  def conn
    @conn ||= PG.connect(ENV.fetch('PANOPTES_DB_URI'), sslmode: 'require')
  end
end
