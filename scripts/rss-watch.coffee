# Description:
#   RSS-Watch
#
# Dependencies:
#   "nodepie": "0.5.0"
#
# Configuration:
#   None
#
# Commands:
#   hubot rss watch <feed url> <interval> - Adds the feed to the watch list with the specified interval in minutes. Default is every 30 minutes.
#   hubot rss unwatch <feed id> - Removes the specified feed from the watch list
#   hubot rss list - Lists all feeds on the watch list & all info
#   hubot rss info <feed id> - Lists all info about the specified feed id
#   hubot rss announce <feed id> <announcement template> - Sets the announcement for new posts
#   hubot rss unannounce <feed id> - Removes announcement from feed id
#   hubot rss set interval for <feed id> to <interval> - In minutes
#   hubot rss start <id> | all
#   hubot rss stop <id> | all
#
# Notes:
#   (\[[^\]]*\]) - (.*) (pushed) \d+ commit\(s\) to ([^\s]+) on ([^\s|\n]+)
#
# Author:
#   jdeeburke

NodePie = require("nodepie")


class Rsswatch
  constructor: (@robot) ->
    @data = {nextFeedIndex: '1', nextAnnouncementsIndex: '1', feeds: {}, announcements: {}}

    @robot.brain.on 'loaded', =>
      if @robot.brain.data.rsswatch
        @data = @robot.brain.data.rsswatch

    return

  addFeed: (feed) ->
    id = @data.nextFeedIndex
    @data.feeds[id] = feed
    @data.nextFeedIndex++
    @saveData()
    return id

  removeFeed: (feedId) ->
    delete @data.feeds[feedId]
    @saveData()

  feedIdForUrl: (url) ->
    for id of @data.feeds
      if @data.feeds[id].url == url
        return id
    return 0

  getFeed: (feedId) -> if @data.feeds[feedId] then @data.feeds[feedId] else null
  
  setFeed: (feedId, feed) -> 
    @data.feeds[feedId] = feed
    @saveData()

  getFeeds: -> @data.feeds
  getAnnouncements: -> @data.announcements

  saveData: -> @robot.brain.data.rsswatch = @data

  addAnnouncement: (announcement) -> 
    id = @data.nextAnnouncementIndex
    @data.announcements[id] = announcement
    @data.nextFeedIndex++
    @saveData()
    return id

  removeAnnouncement: (announceId) ->
    delete @data.announcements[announceId]
    @saveData()


class Feed
  constructor: (@url, @interval, @announce = false, @announceTemplate = '') ->

  @lastItem = ''

  url: -> @url
  interval: -> @interval
  announce: -> @announce
  announceTemplate: -> @announceTemplate

  setUrl: (url) -> @url = url
  setInterval: (interval) -> @interval = interval
  setAnnounce: (announce) -> @announce = announce
  setAnnounceTemplate: (announceTemplate) -> @announceTemplate = announceTemplate

  lastItem: -> @lastItem

#
# @feed is an instantiated Feed object
#
# @match is an object with each key referring to an XML tag for a given item, and each value
#   referring to the regex to use on that data.
#   
#   i.e. If you wanted to match ^(\d+) on the <title> tag and (.*)\n? on the <description> tag, 
#   @match would look like:
#   
#   {
#     title: "^(\d+)",
#     description: "(.*)\n"
#   }
#
# @template is a string with variables that will be populated by the regex matches.
#   The variables will refer to the key of the match as well as the regex match ID like so:
#   @template = "This was post #%%title.1%%" // this will look in the 'title' key for the first regex match
#   
#   To match multiple items, you just use their keys and regex match IDs:
#   @template = "New post on %%pubDate.2%% - %%description.1%%, %%description.2%%"
# 
class Announcement
  constructor: (@name, @match, @template) ->

  name: -> @name
  match: -> @match
  template: -> @template

  setName: (name) -> @name = name
  setMatch: (match) -> @match = match
  setTemplate: (template) -> @template = template

  announce: (rawData) ->

  getMatches: (rawData) ->




module.exports = (robot) ->

  rssWatch = new Rsswatch robot

  # rss watch <url> <interval>
  robot.respond /rss watch ([^\s]+) ?(\d+)?/i, (msg) ->
    url = msg.match[1]
    interval = if msg.match[2] and msg.match[2] != "0" then msg.match[2] else 30
  
    feedId = rssWatch.feedIdForUrl url

    if feedId == 0
      feedId = rssWatch.addFeed new Feed url, interval
      msg.send "Now watching: " + infoStringForFeed feedId
    else
      msg.send "I'm already watching that url... (#" + feedId + ")"

  # rss unwatch <feedId>
  robot.respond /rss (unwatch|stop watching) (\d+)/i, (msg) ->
    feedId = msg.match[2]

    if rssWatch.getFeed feedId
      msg.send "Removed: " + infoStringForFeed feedId
      rssWatch.removeFeed feedId
    else
      msg.send "I don't recognize that feed ID."

  # rss info <feed id>
  robot.respond /rss info (\d+)/i, (msg) ->
    feedId = msg.match[1]
    
    result = infoStringForFeed feedId
    if result == ""
      msg.send "I'm not watching any feeds with that ID."
    else
      msg.send result

  # rss list
  robot.respond /rss list/i, (msg) ->
    for feedId of rssWatch.getFeeds()
      result = infoStringForFeed feedId
      if result != ""
        msg.send result

  # rss set interval for <feed id> to <interval>
  robot.respond /rss set interval for (\d+) to (\d+)/i, (msg) ->
    feedId = msg.match[1]
    interval = msg.match[2]

    if feed = rssWatch.getFeed feedId
      if interval > 0
        rssWatch.setFeed feedId, new Feed feed.url, interval
        msg.send "Updated: " + infoStringForFeed feedId
      else
        msg.send "Invalid interval"
    else
      msg.send "Invalid field ID"

  # rss announce <feed id>
  robot.respond /rss announce (\d+)/i, (msg) ->
    feedId = msg.match[1]

    if feed = rssWatch.getFeed feedId
      if feed.announce
        msg.send "I'm already announcing new entries on feed ##{feedId}"
      else
        newFeed = new Feed feed.url, feed.interval, true, feed.announceTemplate
        rssWatch.setFeed feedId, newFeed
        msg.send "I will now announce all new entries on feed ##{feedId} every #{feed.interval} " + (minuteString feed.interval)
    else
      msg.send "Invalid Feed ID"

  # rss unannounce <feed id>
  robot.respond /rss unannounce (\d+)/i, (msg) ->
    feedId = msg.match[1]

    if feed = rssWatch.getFeed feedId
      if feed.announce
        newFeed = new Feed feed.url, feed.interval, false, feed.announceTemplate
        rssWatch.setFeed feedId, newFeed
        msg.send "I will no longer announce new entries on feed ##{feedId}."
      else
        msg.send "I'm already not announcing new entries on feed ##{feedId}"
    else
      msg.send "Invalid Feed ID"

  # rss start <feed id> | <all>
  robot.respond /rss start ((\d+)|(all))/i, (msg) ->
    if msg.match[3]
      for feedId of rssWatch.getFeeds()
        startFeed feedId, msg
      msg.send "Starting all feeds..."
    else if feedId = msg.match[2]
      msg.send startFeed feedId, msg
    else
      msg.send "Bad Input."

  # rss stop <feed id> | <all>
  robot.respond /rss stop ((\d+)|(all))/i, (msg) ->
    if msg.match[3]
      for feedId of rssWatch.getFeeds()
        stopFeed feedId, msg
      msg.send "Stopping all feeds..."
    else if feedId = msg.match[2]
      msg.send stopFeed feedId, msg
    else
      msg.send "Bad Input."

  # rss new announcement <name> :: <match> :: <template>
  robot.respond /rss new announcement (.*)(?! :: )*( :: )(.*)(?! :: )*( :: )(.*)/i, (msg) ->
    name = msg.match[1]
    match = msg.match[3]
    template = msg.match[5]

    announcement = new Announcement name, match, template
    announceId = rssWatch.addAnnouncement announcement
    msg.send "Ok, I created your announcement (##{announceId})"


  startFeed = (feedId) ->
    if feed = rssWatch.getFeed feedId
      msg.http(feed.url).get() (err, res, body) ->
        if res.statusCode is not 200
          msg.send "Problem with feed ##{feedId}"
        else
          feed = new NodePie(body)
          try
            
          catch e
            
          
    else
      return "Invalid Feed ID"


  stopFeed = (feedId) ->
    if feed = rssWatch.getFeed feedId

    else
      return "Invalid Feed ID"


  infoStringForFeed = (feedId) ->
    if feed = rssWatch.getFeed feedId
      infoString = "(#{feedId}) #{feed.url} - refresh"
      infoString += if feed.announce then " & announce" else ""
      infoString += " every #{feed.interval} " + minuteString feed.interval
      return  infoString
    else
      return ""

  minuteString = (value) -> if value == "1" then "minute" else "minutes"