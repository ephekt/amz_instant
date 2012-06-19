# coding: utf-8

#TODO
## USE TSOCKS!!! http://pyvideo.org/video/609/web-scraping-reliably-and-efficiently-pull-data about 1:30 in to the movie
## http://railspro.blogspot.com/2011/04/setting-user-agent-in-typhoeus_3322.html
## CookieJars http://stackoverflow.com/questions/9810150/manually-login-into-website-with-typheous
## PiCloud http://docs.picloud.com/advanced_examples.html

=begin
  Creative URL Mapper
  Designed & Developed by Optimization Solutions Development, Display Advertising
  Goal: Given an original_tag from a creative, find the landing page and record to a database
  Possible Enhancements: Validate previously logged landing pages and ensure they map correctly
  Env Reqs: Windows [AutoIT, Ruby, all gems listed], Mac OS X [cliclick binary, Ruby, all gems listed]
=end

#!/usr/bin/env ruby

require 'rubygems'
require 'typhoeus'
require 'mechanize'
require 'nokogiri'
# require 'vapir'
# require 'mysql'

#Runner.new

class Mech
  @agent = nil
  def initialize
    @agent = Mechanize.new { |agent|
      agent.user_agent_alias = 'Mac Safari'
    }
    all_items
    #login_to_amazon #only if needed
  end
  
  def login_to_amazon
    unless ENV['AMZ_EMAIL'] && ENV['AMZ_PASSWORD']
      raise "Set AMZ_EMAIL & AMZ_PASSWORD ENV Vars"
    end
    p = @agent.get("http://www.amazon.com/gp/yourstore/home/ref=pd_ys_home_signin?ie=UTF8&signIn=1")
    
    if p.body.include?("Michael's Amazon.com")
      puts "Already signed in..."
      return true
    end

    r = p.form_with(:id => "ap_signin_form") do |f| 
      f.email = ENV['AMZ_EMAIL']
      f.password = ENV['AMZ_PASSWORD']
    end.submit
    
    File.open("output.html","w") {|f| f.write(r.body) }
    
    r.body.include?("Michael's Amazon.com")
  end
  
  def all_items
    set = {
      # movie: @agent.get("http://www.amazon.com/gp/search/other?redirect=true&rh=n%3A2625373011%2Cp_n_format_browse-bin%3A2650306011%2Cn%3A%212625374011%2Cn%3A2649512011&bbn=2625374011&pickerToList=theme_browse-bin&ie=UTF8&qid=1340067362&rd=1").search(".c3_ref.refList a"),
      tv: @agent.get("http://www.amazon.com/gp/search/other?redirect=true&rh=n%3A2625373011%2Cn%3A%212644981011%2Cn%3A%212644982011%2Cn%3A2858778011%2Cn%3A2864549011&bbn=2864549011&pickerToList=theme_browse-bin&ie=UTF8&qid=1340066883&rd=1").search(".c3_ref.refList a")
    }
        
    set.each do |medium,anchors|
      puts "Working on #{medium}'s"
      anchors.each do |a|
        genre = a.inner_text.split("(")[0].strip
        puts "Fetching #{medium}::#{genre} -> http://www.amazon.com#{a['href']}"
        
        p = @agent.get("http://www.amazon.com#{a['href']}")
        
        begin
          total_count = p.at("#resultCount").inner_text.scan(/[0-9,]+/).last.gsub(',','').to_i
          total_pages = (total_count/12)+1
        rescue Exception => e
          puts "Failed to find total_count/pages - #{e}"
          return
        end
        
        puts "Items: #{total_count}, Pages: #{total_pages}"

        upper_bound = 4800
        page_sort = false
        case
        when total_count > 9600
          puts "We will miss out on #{total_count-9600} items due to size"
        when total_count > upper_bound
          puts "we got a big one and we'll need to sort #{total_count}"
          page_sort = true
        else
          puts "Doable without work!"
        end

        
        hydra = Typhoeus::Hydra.new(:max_concurrency => 2)

        1.upto(total_pages) do |page_number|
          # Not-so-fault tolerant way to grab pages.
          # Assume each page is relatively static from Amazon and
          # do not re-process pages for now
          file = "pages/#{medium}_#{genre.gsub(/\W+/,'')}_#{page_number}.html"
          next if File.exists?(file)
          puts "Working on page: #{file}"
          request = Typhoeus::Request.new("http://www.amazon.com#{a['href']}&page=#{page_number}")
          request.on_complete do |response|
            File.open(file,"w") { |f| f.write response.body }
          end
          hydra.queue request
        end
        hydra.run
        exit
      end
    end
  end
end

Mech.new