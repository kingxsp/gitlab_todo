#!/usr/bin/env ruby
#encoding: utf-8

require 'gitlab'

# [TODO: check if gitlab host or token if set]
$new_todo = []
$old_todo = []

def pt(todo, sign, file_name)

  if sign == '-'
    $old_todo << { :todo => todo, :file_name => file_name }
  elsif sign == '+'
    $new_todo << { :todo => todo, :file_name => file_name }
  end

end

def add_issues(todos)

  project = get_current_project
  my_user_id = get_current_user_id
  todos.each do |todo|
    puts "add todo [#{todo}]"
    Gitlab.create_issue(project.id, todo[:todo], {:labels => 'todo', :assignee_id => my_user_id,
        :description => todo[:file_name] })
  end

end

def close_issues(todos)

  project = get_current_project
  issues = Gitlab.issues(project.id)

  todos.each do |todo|
    issues.each do |issue|
      if issue.title == todo[:todo] and issue.labels.include?('todo') and issue.state == 'opened'
        puts "close todo [#{issue.id}: #{todo}]"
        Gitlab.close_issue(project.id, issue.id)
      end
    end
  end

end

# main
def main

  ci = `git diff HEAD^ HEAD`

  ext = 'rb'
  file_name = nil

  ci.split("\n").each do |line|

    file_ext = /diff --git a\/(\w*\/){0,}(\w*)\.(\w*)/.match(line)
    diff_line = /^[-|+]\s*/.match(line)

    if file_ext.nil? and not diff_line.nil?
      case ext
      when 'rb'
        # ruby source
        if line.gsub(/^[-|+]\s*/, "")[0] == '#'
          tm = /#\s*(\[TODO:)(.*)(\])/.match(line)
          unless tm.nil?
            todo = tm[2]
            todo.gsub!(/^\s*/,"").gsub!(/\s*$/,"")
            pt todo, line[0], file_name
          end
        end
      when 'php','java'
        # comment use // or /** */
        if not /\/\/*/.match(line.gsub(/^[-|+]\s*/, "")).nil? or not /\/\**/.match(line.gsub(/^[-|+]\s*/, "")).nil?

          tm = /\s*(\[TODO:)(.*)(\])/.match(line)
          unless tm.nil?
            todo = tm[2]
            todo.gsub!(/^\s*/,"").gsub!(/\s*$/,"")
            pt todo, line[0], file_name
          end
        end
      end
    elsif not file_ext.nil? and file_ext.size == 4
      ext = file_ext[3].downcase
      file_name = file_ext[0].gsub(/diff --git a\//,"")
      #puts "file ext is #{ext}"
    end
  end

  # create or close issus
  add_issues($new_todo - $old_todo)
  close_issues($old_todo - $new_todo)
end

def get_current_project
  # list projects
  projects = Gitlab.projects()
  local = `git remote -v`
  local.split("\n").each do |line|
    projects.each do |project|
      return project if line.index(project.ssh_url_to_repo)
    end
  end
  nil
end

def get_current_user_id
  user = Gitlab.user()
  user.id
end

# export GITLAB_HOST = ...
# export GITLAB_TOKEN = ...
Gitlab.endpoint = ENV['GITLAB_HOST']
Gitlab.private_token = ENV['GITLAB_TOKEN']

main
