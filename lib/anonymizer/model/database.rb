# Basic class to communication with databese
class Database
  attr_accessor :config, :name

  def initialize(config)
    @config = config
    @db = Sequel.mysql(
      @config['database']['name'],
      user: CONFIG['database']['user'],
      host: CONFIG['database']['host'],
      password: CONFIG['database']['pass']
    )
  end

  def anonymize
    insert_fake_data

    @config['tables'].each do |table_name, columns|
      querys = column_query(table_name, columns)

      querys.each do |query|
        @db.run query
      end
    end

    remove_fake_data
  end

  def column_query(table_name, columns)
    querys = []

    columns.each do |column_name, info|
      Object.const_get(
        "Database::#{translate_acton_to_class_name(info['action'])}"
      ).query(table_name, column_name, info).each do |query|
        querys.push query
      end

      break if info['action'] == 'truncate'
    end

    querys
  end

  def insert_fake_data
    Fake.create_fake_user_table @db

    fake_user = @db[:fake_user]

    100.times do
      fake_user.insert(Fake.user)
    end
  end

  def remove_fake_data
    @db.drop_table :fake_user
  end

  # rubocop:disable Metrics/MethodLength
  def translate_acton_to_class_name(action)
    case action
    when 'truncate'
      class_name = 'Truncate'
    when 'empty', 'set_static'
      class_name = 'Static'
    when 'eav_update'
      class_name = 'Eav'
    when 'json_update'
      class_name = 'Json'
    else
      class_name = 'Column'
    end

    class_name
  end
  # rubocop:enable Metrics/MethodLength

  def self.prepare_select_for_query(type)
    query = if type == 'email'
              "SELECT REPLACE(fake_user.email, '$uniq$', CONCAT('+', UUID_SHORT())) "
            elsif type == 'login'
              "SELECT REPLACE(fake_user.login, '$uniq$', CONCAT('+', UUID_SHORT())) "
            elsif type == 'fullname'
              "SELECT CONCAT_WS(' ', fake_user.firstname, fake_user.lastname) "
            else
              "SELECT fake_user.#{type} "
            end

    query
  end
end
