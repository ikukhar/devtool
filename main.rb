require 'gtk3'
require 'net-ldap'
require 'git'
require 'tiny_tds'
require 'open3'
require 'win32api'

require_relative 'devtool'
require_relative 'handler'
require_relative 'redmine'


Encoding.default_external = 'utf-8'

BASEDIR = 'D:/v7_base.git/'      
DEVELOPER = ENV['USERNAME']
EDITOR = 'akelpad'

Devtool.new
