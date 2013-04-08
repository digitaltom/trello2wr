
require 'rubygems'
require 'trello'
require 'yaml'
require 'uri'

CONFIG = YAML.load_file(File.expand_path(File.dirname(File.dirname(__FILE__)), 'config.yml'))

class Workreport
  attr_reader :config, :user, :year, :week

  def initialize
    @year = Date.today.year
    @week = Date.today.cweek
    @user = sign_in
  end

  # Get Trello cards
  def sign_in
    Trello.configure do |config|
      config.developer_public_key = CONFIG["default"]["trello_developer_public_key"]
      config.member_token = CONFIG["default"]["trello_member_token"]
    end

    Trello::Member.find(CONFIG["default"]["trello_username"])
  end

  def done
    last_week = self.week-1
    done = self.user.boards.first.lists.find{|l| l.name == "Done (#{self.year}##{last_week})"}
    cards = done.cards.select{|card| card.member_ids.include? self.user.id}
    cards.map{|c| "- #{c.name.downcase}\n"}
  end

  def doing
    done = self.user.boards.first.lists.find{|l| l.name == "Doing"}
    cards = done.cards.select{|card| card.member_ids.include? self.user.id}
    cards.map{|c| "- #{c.name.downcase} [WIP]\n"}
  end

  def todo
    done = self.user.boards.first.lists.find{|l| l.name == "To Do"}
    cards = done.cards.select{|card| card.member_ids.include? self.user.id}
    cards.map{|c| "- #{c.name.downcase}\n"}
  end

  # Prepare A&O mail
  def subject
    self.escape("A&O Week ##{self.week} #{self.user.username}")
  end

  def body
    body = "Accomplishments:\n"
    self.done.each{|line| body += line}

    body += "\nObjectives:\n"
    self.doing.each{|line| body += line}
    self.todo.each{|line| body += line}

    self.escape(body)
  end

  def construct_mail_to_url(recipient, subject, body)
    URI::MailTo.build({:to => recipient, :headers => {"subject" => subject, "body" => body}}).to_s.inspect
  end

  def escape(string)
    URI.escape(string, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
  end

  def prepare
    mailto = self.construct_mail_to_url(CONFIG["default"]["recipient"], self.subject, self.body)
    system("thunderbird #{mailto}")
  end
end


ao = Workreport.new
ao.prepare