####################################################################################################
# VDR Live TV Plugin V 0.0.2 alpha
# written by Alexander Damhuis in 2013/2014
# based on the Dreambox Plugin by greeny
#
# this is free code, do whatever you want with it!
# (MIT License)
####################################################################################################

ART = 'art-default.jpg'
ICON = 'icon-default.png'
REGEX = '%s = new Array\((.+?)\);'
CHANNELS_URL = 'http://%s:%s/channels.xml'
LISTGROUPS_URL = 'http://%s:%s/channels/groups.xml' 
SINGLEGROUP_URL= 'http://%s:%s/channels.xml?group=%s'
CHANNELIMAGE_URL = 'http://%s:%s/channels/image/%s'
CHANNELEPG_CURRENT_URL = 'http://%s:%s/events/%s.xml?start=0&limit=%s'
CHANNELEPG_IMAGE_URL = 'http://%s:%s/events/image/%s/%s'

STREAM_URL = 'http://%s:%s/%s/%s'

NAMESPACESGROUP = {'group': 'http://www.domain.org/restfulapi/2011/groups-xml'}
NAMESPACESCHANNEL = {'channel': 'http://www.domain.org/restfulapi/2011/channels-xml'}
NAMESPACEEPG = {'epg': 'http://www.domain.org/restfulapi/2011/events-xml'}


####################################################################################################
def Start():

	Plugin.AddViewGroup('List', viewMode='List', mediaType='items')
	ObjectContainer.art = R(ART)
	ObjectContainer.title1 = 'VDR Live TV'
	DirectoryObject.thumb = R(ICON)
	Resource.AddMimeType('image/png','png')
	# Da sollte noch ein "initial Channel/EPG" und eine Art "Close Stream" hook hin, oder ?

####################################################################################################
@handler('/video/vdr', 'VDR Streamdev Client', art=ART, thumb=ICON)
def MainMenu():

	groupListContainer = ObjectContainer(view_group='List', no_cache=True)

	if Prefs['host'] and Prefs['port'] and Prefs['stream']:
		xml = LISTGROUPS_URL % (Prefs['host'], Prefs['restapi'])
		
		try:
			GroupList = XML.ElementFromURL(xml)
		
		except:
			Log("VDR Plugin: Couldn't connect to VDR.") 
			return None

		Log("Loading VDR GroupsList via restfulapi-plugin at Port %s" % (Prefs['restapi']))

		numberOfGroups = int(GroupList.xpath('//group:count/text()', namespaces=NAMESPACESGROUP)[0])

		item = 0
		for item in range(numberOfGroups):
			#jeden Namen einzeln holen aus dem XPath Object statt aus der Liste
			groupName = GroupList.xpath('//group:group/text()', namespaces=NAMESPACESGROUP)[item]
			groupListContainer.add(DirectoryObject(key = Callback(DisplayGroupChannels, name=groupName), title = groupName))

	groupListContainer.add(PrefsObject(title='Preferences', thumb=R('icon-prefs.png')))

	return groupListContainer

#################################################################################

@route("/video/vdr/DisplayGroupChannels")
def DisplayGroupChannels(name):

	Log("Aufruf von DisplayGroupChannels %s" % (name))
	
	groupNameURLconform = name.replace(" ", "%20")


	xml = SINGLEGROUP_URL % (Prefs['host'], Prefs['restapi'], groupNameURLconform)
	try:
		Log("VDR Plugin: Loading channels.") 
		channelGroupList = XML.ElementFromURL(xml)
	except:
		Log("VDR Plugin: Couldn't get channels.") 
		return None

	numberOfChannels = int(channelGroupList.xpath('//channel:count/text()', namespaces=NAMESPACESCHANNEL)[0])
	
	channelListContainer = ObjectContainer(title2=name, view_group='List', no_cache=True)

	item = 0
	Channel_ID = ""
	Channel_Name= ""

	for item in range(numberOfChannels):

		Channel_Name = channelGroupList.xpath('//channel:param[@name="name"]/text()', namespaces=NAMESPACESCHANNEL)[item]
		Channel_ID = channelGroupList.xpath('//channel:param[@name="channel_id"]/text()', namespaces=NAMESPACESCHANNEL)[item]
		hasChannelLogo = channelGroupList.xpath('//channel:param[@name="image"]/text()', namespaces=NAMESPACESCHANNEL)[item]

		channelListContainer.add(LiveTVMenu(sender=Channel_Name, channel=Channel_ID, thumb=hasChannelLogo))

	return channelListContainer

####################################################################################################
@route("/video/vdr/LiveTVMenu")
def LiveTVMenu(sender, channel, thumb, include_oc=False):

	if (thumb == "true"):
		Log("Channellogo found")
		thumb = CHANNELIMAGE_URL % (Prefs['host'], Prefs['restapi'], channel)
	else:
		Log("No channel Logo in data")
		thumb = R(ICON)

	currentEpgXml = CHANNELEPG_CURRENT_URL % (Prefs['host'], Prefs['restapi'], channel, "1")

	try:
		Log("Loading current EPG for %s" % channel) 

		currentEpg = XML.ElementFromURL(currentEpgXml, encoding='UTF8')
		#get all the stuff for the VideoClipObject
		
		currentEvent = currentEpg.xpath('//epg:param[@name="id"]/text()', namespaces=NAMESPACEEPG)

		currentTitle = currentEpg.xpath('//epg:param[@name="title"]/text()', namespaces=NAMESPACEEPG)[0]
		currentSubtitle = currentEpg.xpath('//epg:param[@name="short_text"]/text()', namespaces=NAMESPACEEPG)[0]
		currentDescription = currentEpg.xpath('//epg:param[@name="description"]/text()', namespaces=NAMESPACEEPG)[0]
		currentDuration = currentEpg.xpath('//epg:param[@name="duration"]/text()', namespaces=NAMESPACEEPG)[0]

		currentEpgImage = CHANNELEPG_IMAGE_URL % (Prefs['host'], Prefs['restapi'], currentEvent, "0")

	except:
		Log("VDR Plugin: Couldn't get EPG") 
		currentTitle = "no data"
		currentSubtitle = "no data"
		currentDescription = "no data"
		currentDuration = "3600"
		currentEpgImage = thumb
		#return None

	video = VideoClipObject(

		key = Callback(LiveTVMenu, sender=sender, channel=channel, thumb=currentEpgImage, include_oc=True),
		#studio = sender, 
		title = ("%s | %s" % (sender, currentTitle)),
		#original_title = currentTitle,
		#source_title = sender,
		#tagline = currentTitle,
		summary = currentDescription,
		#duration = int(currentDuration),
		rating_key = currentTitle,
		thumb = thumb,
		items = [
			MediaObject(
						container               = 'mpegts',
            			video_codec             = VideoCodec.H264,
            			optimized_for_streaming = True,
				parts = [PartObject(key=Callback(PlayVideo, channel=channel, duration=currentDuration))]
			)
		]
	)

	if include_oc:
		oc = ObjectContainer()
		oc.add(video)
		return oc
	else:
		return video


####################################################################################################
@route("/video/vdr/PlayVideo/{channel}")
def PlayVideo(channel, duration):

	#generate the URL to the Stream
	stream = STREAM_URL % (Prefs['host'], Prefs['port'], Prefs['stream'],channel)
#	Log(stream)


	playList = "#EXTM3U" + "\n"
	playList = playList + "#EXT-X-VERSION:3" + "\n"
	playList = playList + "#EXT-X-TARGETDURATION:3600" + "\n"
	playList = playList + "#EXTINF:3600," + "\n"
	playList = playList + stream + "\n"
	playList = playList + "#EXT-X-ENDLIST" + "\n"

	Log(playList)

#	return Redirect(stream)
	return playList
