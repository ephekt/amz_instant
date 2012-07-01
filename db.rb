# coding: utf-8

require "rubygems"
require 'bundler'

Bundler.require

files = Dir.glob("pages/*.html")

puts "Inspecting pages...#{files.size}"

DB = Mongo::Connection.new.db('amz_instant')

collection = DB.collection('media')

files.each_with_index do |file,index|
  puts "File ##{index} #{file}"
  Nokogiri::HTML(File.read(file)).search('div.product').each do |product|
    amz_id  = product['name']
        
    if obj = collection.find_one({:amz_id => amz_id})
      # puts "Existing #{amz_id}"
    else
      
      thumb       = product.search("img.productImage").first['src'] rescue "N/A"
      anchor      = product.search("a.title").first
      title       = anchor.inner_text
      link        = anchor['href']
      media_type  = file.scan(/movie|tv/).first
    
      if title.empty?
        puts product.inspect
        exit
      end
      
      # puts "New #{amz_id}"
      collection.insert({
        amz_id: amz_id,
        thumbnail: thumb,
        title: title,
        link: link,
        media_type: media_type
      })
    end
  end
end