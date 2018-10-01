require 'trello'
require 'yaml'
require 'uri'

class Trello2WR
  include Trello
  include Trello::Authorization

  attr_reader :user, :board, :week
  @@debug = true

  def initialize()
    @config = load_config

    authenticate

    @username = @config['trello']['username']
    @user = find_member(@username)
    @board = find_board
  end

  def authenticate
    Trello::Authorization.const_set :AuthPolicy, OAuthPolicy
    OAuthPolicy.consumer_credential = OAuthCredential.new @config['trello']['developer_public_key'], @config['trello']['developer_secret']
    OAuthPolicy.token = OAuthCredential.new @config['trello']['member_token'], nil
  end

  def load_config
    # Read keys from ~/trello2wr/config.yml
    if File.exist? File.expand_path("~/.trello2wr/config.yml")
      YAML.load_file(File.expand_path("~/.trello2wr/config.yml"))
    else
      raise "ERROR: Config file not found!"
    end
  end

  def find_member(username)
    self.log("*** Searching for user '#{username}'")

    begin
      Member.find(username)
    rescue Trello::Error
      raise "ERROR: user '#{username}' not found!}"
    end
  end

  def find_board
    board_name = @config['trello']['boards'].first
    self.log("*** Searching for board '#{board_name}'")
    board = @user.boards.find{|b| b.name == board_name}
    raise "ERROR: Board '#{board_name}' not found!" unless board
    board
  end

  def cards(board, list_name)
    self.log("*** Getting cards for '#{list_name}' list in board '#{board}'")
    lists = @board.lists
    list = lists.detect{|l| l.name == list_name}
    if list
      return list.cards.reject{|c| ["Fast Lane", "WIP", "README", "Please remember"].any? { |word| c.name.include?(word) } }
    else
      raise "ERROR: List '#{list_name}' not found!"
    end
  end

  # Prepare mail body
  def body
    body = ''

    body += "  Done:\n"
    @board.lists.select{|l| l.name.include?('Done 20') }.map(&:name).each do |list_name|
      self.cards(board, list_name).each do |card|
        body += "  - #{card.name}\n"
      end
    end
    body += "\n  Ongoing:\n"
    ['Demo [5]', 'In Review [4]', 'Dev - Done', 'Dev - In Progress'].each do |list_name|
      self.cards(board, list_name).each do |card|
        body += "  - #{card.name}\n"
      end
    end
    body += "\n  Blocked:\n"
    ['Blocked'].each do |list_name|
      self.cards(board, list_name).each do |card|
        body += "  - #{card.name}\n"
      end
    end
    body += "\n  Next:\n"
    ['Planned [4]', 'To Do [4]'].each do |list_name|
      self.cards(board, list_name).each do |card|
        body += "  - #{card.name}\n"
      end
    end


    body
  end

  def escape(string)
    URI.escape(string, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
  end

  def log(message)
    puts message if @@debug
  end
end
