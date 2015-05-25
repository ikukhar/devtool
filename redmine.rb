require 'active_resource'

module Redmine
	
	class RedmineAPI < ActiveResource::Base
		self.site = 'http://web-station:83/'
		self.user = 'i.kukhar'
		self.password = 'Ybrbnf'
		self.format = :xml
	end 

	class Issue < RedmineAPI; end
	class User < RedmineAPI; end


	Encoding.default_external = 'utf-8'

	def self.mytasks
		
		onec77 		 = 2
		developers = 21

		devs = User.find(:all, params: {group_id: developers})
		user = devs.select{ |dev| dev.login == DEVELOPER}.first.attributes[:id]

		issues = Issue.find(:all, params: {project_id: onec77, assigned_to_id: user})

		issues

	end

	def self.open_issue_in_browser id
		`start #{RedmineAPI.site}issues/#{id}` 
	end

	def self.create_new_issue_in_browser
		`start #{RedmineAPI.site}projects/2/issues/new` 
	end
end