require 'octokit'
require 'pry'
require 'excon'
require 'colored'
require 'json'

module Fastlane
  class Bot
    SLUG = ENV['REPO_TO_REAP']
    ISSUE_WARNING = 0.75
    ISSUE_CLOSED = 0.25 # plus the x months from ISSUE_WARNING

    # Labels
    SCHEDULED_FOR_REAPING = "scheduled-for-reaping"
    REAPED = "reaped"
    DO_NOT_REAP = 'do-not-reap'
    LABELS_TO_REAP = "operations"

    def client
      @client ||= Octokit::Client.new(access_token: ENV["GITHUB_API_TOKEN"])
    end

    def start(process: :issues)
      # Heroku is already complaining about memory size, and auto_paginate
      # makes the client bring all of the objects into memory at once. This
      # can only continue to get worse, since we look at every issue ever.
      client.auto_paginate = false

      puts "Fetching issues and PRs from '#{SLUG}'..."

      # Doing pagination ourself is a pain, but it's important for keeping a
      # reasonable memory footprint
      page = 1
      issues_page = fetch_issues(page)

      while issues_page && issues_page.any?
        # It's important that we check this immediately, as calls we make during
        # processing will affect the last_response
        has_next_page = !!client.last_response.rels[:next]

        issues_page.each do |issue|
          if process == :issues && issue.pull_request.nil?
            puts "Investigating issue ##{issue.number}..."
            process_open_issue(issue) if issue.state == "open"
          end
        end

        page += 1
        # If there's a next page, keep going
        issues_page = has_next_page ? fetch_issues(page) : nil
      end

      puts "[SUCCESS] I worked through issues, much faster than human beings, bots will take over"
    end

    def fetch_issues(page = 1)
      # issues includes PRs, and since the pull_requests API doesn't include
      # labels, it's actually important that we query everything this way!
      client.issues(SLUG, per_page: 100, state: "all", page: page, labels: LABELS_TO_REAP)
    end

    def process_open_issue(issue)
      process_inactive(issue)
      return if issue.comments > 0 # there maybe already some bot replys
    end

    def myself
      client.user.login
    end

    def has_label?(issue, label_name)
      issue.labels? && !!issue.labels.find { |label| label.name == label_name }
    end

    # Responsible for commenting to inactive issues, and closing them after a while
    def process_inactive(issue)
      return if has_label?(issue, DO_NOT_REAP) # Ignore issues tagged do-not-reap

      diff_in_months = (Time.now - issue.updated_at) / 60.0 / 60.0 / 24.0 / 30.0

      warning_sent = !!issue.labels.find { |a| a.name == SCHEDULED_FOR_REAPING }
      if warning_sent && diff_in_months > ISSUE_CLOSED
        # We sent off a warning, but we have to check if the user replied
        if client.issue_comments(SLUG, issue.number).last.user.login == myself
          # No reply from the user, let's close the issue
          puts "https://github.com/#{SLUG}/issues/#{issue.number} (#{issue.title}) is #{diff_in_months.round(1)} months old, closing now"
          body = []
          body << "This issue will be auto-closed because there hasn't been any activity for a month. Feel free to [open a new one](https://github.com/#{SLUG}/issues/new) if you still experience this problem 👍"
          client.add_comment(SLUG, issue.number, body.join("\n\n"))
          client.close_issue(SLUG, issue.number)
          client.add_labels_to_an_issue(SLUG, issue.number, [REAPED])
        else
          # User replied, let's remove the label
          puts "https://github.com/#{SLUG}/issues/#{issue.number} (#{issue.title}) was replied to by a different user"
          client.remove_label(SLUG, issue.number, SCHEDULED_FOR_REAPING)
        end
        smart_sleep
      elsif diff_in_months > ISSUE_WARNING
        return if issue.labels.find { |a| a.name == SCHEDULED_FOR_REAPING }

        puts "https://github.com/#{SLUG}/issues/#{issue.number} (#{issue.title}) is #{diff_in_months.round(1)} months old, pinging now"
        body = []
        body << "There hasn't been any activity on this issue recently. To keep us focused, we have to clean some of the old issues, as many of them have already been resolved with the latest updates."
        client.add_comment(SLUG, issue.number, body.join("\n\n"))
        client.add_labels_to_an_issue(SLUG, issue.number, [SCHEDULED_FOR_REAPING])
        smart_sleep
      end
    end

    def smart_sleep
      sleep 5
    end
  end
end
