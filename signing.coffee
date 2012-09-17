#window.search_process is the entry point

window.return_container = {}

window.invokeRequest = ->
  if getAccessKeyId() is "AWS Access Key ID"
    alert "Please provide an AWS Access Key ID"
    return
  if getSecretAccessKey() is "AWS Secret Access Key"
    alert "Please provide an AWS Secret Access Key"
    return
  unsignedUrl = document.getElementById("UnsignedURL").value
  if unsignedUrl is ""
    alert "Please provide a URL"
    return
  lines = unsignedUrl.split("\n")
  unsignedUrl = ""
  for i of lines
    unsignedUrl += lines[i]
  
  # find host and query portions
  urlregex = new RegExp("^http:\\/\\/(.*)\\/onca\\/xml\\?(.*)$")
  matches = urlregex.exec(unsignedUrl)
  unless matches?
    alert "Could not find PA-API end-point in the URL. Please ensure the URL looks like the example provided."
    return
  host = matches[1].toLowerCase()
  query = matches[2]
  
  # split the query into its constituent parts
  pairs = query.split("&")
  
  # remove signature if already there
  # remove access key id if already present
  #  and replace with the one user provided above
  # add timestamp if not already present
  pairs = cleanupRequest(pairs)
  
  # show it
  document.getElementById("NameValuePairs").value = pairs.join("\n")
  
  # encode the name and value in each pair
  pairs = encodeNameValuePairs(pairs)
  
  # sort them and put them back together to get the canonical query string
  pairs.sort()
  document.getElementById("OrderedPairs").value = pairs.join("\n")
  canonicalQuery = pairs.join("&")
  stringToSign = "GET\n" + host + "\n/onca/xml\n" + canonicalQuery
  
  # calculate the signature
  secret = getSecretAccessKey()
  signature = sign(secret, stringToSign)
  
  # assemble the signed url
  signedUrl = "http://" + host + "/onca/xml?" + canonicalQuery + "&Signature=" + signature
  
  # update the UI
  stringToSignArea = document.getElementById("StringToSign")
  stringToSignArea.value = stringToSign
  signedURLArea = document.getElementById("SignedURL")
  signedURLArea.value = signedUrl

window.search_item = ( item ) ->
  unsignedUrl = """http://ecs.amazonaws.com/onca/xml?Service=AWSECommerceService
  &Version=2009-03-31
  &Operation=ItemSearch
  &ResponseGroup=ItemAttributes,Offers,Images
  &SearchIndex=All
  &Keywords=#{ item }"""  
  
  unsignedUrl = unsignedUrl + "\n&AssociateTag=thedealpandac-20"
  
  lines = unsignedUrl.split("\n")
  unsignedUrl = ""
  for i of lines
    unsignedUrl += lines[i]
    
  # find host and query portions
  urlregex = new RegExp("^http:\\/\\/(.*)\\/onca\\/xml\\?(.*)$")
  matches = urlregex.exec(unsignedUrl)
  unless matches?
    console.log("Could not find PA-API end-point in the URL. Please ensure the URL looks like the example provided.")
    return
  host = matches[1].toLowerCase()
  query = matches[2]    

  # split the query into its constituent parts
  pairs = query.split("&")
  
  # remove signature if already there
  # remove access key id if already present
  #  and replace with the one user provided above
  # add timestamp if not already present
  pairs = cleanupRequest(pairs)
  
  # encode the name and value in each pair
  pairs = encodeNameValuePairs(pairs)
  
  # sort them and put them back together to get the canonical query string
  pairs.sort()
  canonicalQuery = pairs.join("&")
  stringToSign = "GET\n" + host + "\n/onca/xml\n" + canonicalQuery      

  # calculate the signature
  secret = getSecretAccessKey()
  signature = sign(secret, stringToSign)
  
  # assemble the signed url
  signedUrl = "http://" + host + "/onca/xml?" + canonicalQuery + "&Signature=" + signature
  
  return signedUrl

window.call_api = ( url, word ) ->
  xhr = new XMLHttpRequest()
  
  xhr.open("GET", url)
  #xhr.setRequestHeader("Content-Type","application/x-www-form-urlencoded")
  xhr.onreadystatechange = (status, response) =>
    
    if xhr.readyState is 4
    
      console.log("xhr", xhr)
      console.log("TOKEN RETRIEVAL LOGGED")
      #console.log("response: ", xhr.response)
      
      window.obj = $.xml2json(xhr.response)
      console.log("OBJ", window.obj)
      window.process_items( window.obj )
            
  xhr.send()
  window.xhr = xhr

window.search_process = ( searchword ) ->
  url = window.search_item ( searchword )
  window.call_api(url, searchword)

window.camping_list = ["flashlight", "tent", "grill", "canoe", "lighter", "binoculars", "rope", "iPod", "iPad", "Nexus", "Kindle", "cumin", "cheddar cheese", "black pepper"]

window.populate_list = ()->
  
  for word in window.camping_list
    window.search_process( word)

window.stored_items = {}
window.process_items = ( query ) ->

  #most_relevant = query["Items"]["SearchResultsMap"]["SearchIndex"][0]["ASIN"][0]
  #console.log("most relevant", most_relevant)
  
  search_size = query["Items"]["Item"].length - 1
  search_size = 4 if search_size > 5
  
  console.log("search", [0..search_size])
  
  for index in [0..search_size]
    
    x = query["Items"]["Item"][index]
    #console.log("Data", x)
    pulled_data = {}
    pulled_data["url"] = x["DetailPageURL"]
    pulled_data["price"] = x["ItemAttributes"]["ListPrice"]["FormattedPrice"] if x["ItemAttributes"]["ListPrice"]?
    pulled_data["title"] = x["ItemAttributes"]["Title"]
    pulled_data["ASIN"] = x["ASIN"]
    pulled_data["real_price"] = x["OfferSummary"]["LowestNewPrice"]["FormattedPrice"] if x["OfferSummary"]["LowestNewPrice"]?
    pulled_data["image"] = x["MediumImage"]["URL"]
    
    console.log("pulled data: ", pulled_data)
    
    #window.stored_items[key] = pulled_data
  
window.encodeNameValuePairs = (pairs) ->
  i = 0

  while i < pairs.length
    name = ""
    value = ""
    pair = pairs[i]
    index = pair.indexOf("=")
    
    # take care of special cases like "&foo&", "&foo=&" and "&=foo&"
    if index is -1
      name = pair
    else if index is 0
      value = pair
    else
      name = pair.substring(0, index)
      value = pair.substring(index + 1)  if index < pair.length - 1
    
    # decode and encode to make sure we undo any incorrect encoding
    name = encodeURIComponent(decodeURIComponent(name))
    value = value.replace(/\+/g, "%20")
    value = encodeURIComponent(decodeURIComponent(value))
    pairs[i] = name + "=" + value
    i++
  pairs
  
window.cleanupRequest = (pairs) ->
  haveTimestamp = false
  haveAwsId = false
  accessKeyId = getAccessKeyId()
  nPairs = pairs.length
  i = 0
  while i < nPairs
    p = pairs[i]
    unless p.search(/^Timestamp=/) is -1
      haveTimestamp = true
    else unless p.search(/^(AWSAccessKeyId|SubscriptionId)=/) is -1
      pairs.splice i, 1, "AWSAccessKeyId=" + accessKeyId
      haveAwsId = true
    else unless p.search(/^Signature=/) is -1
      pairs.splice i, 1
      i--
      nPairs--
    i++
  pairs.push "Timestamp=" + getNowTimeStamp()  unless haveTimestamp
  pairs.push "AWSAccessKeyId=" + accessKeyId  unless haveAwsId
  pairs
  
window.sign = (secret, message) ->
  messageBytes = str2binb(message)
  secretBytes = str2binb(secret)
  secretBytes = core_sha256(secretBytes, secret.length * chrsz)  if secretBytes.length > 16
  ipad = Array(16)
  opad = Array(16)
  i = 0

  while i < 16
    ipad[i] = secretBytes[i] ^ 0x36363636
    opad[i] = secretBytes[i] ^ 0x5C5C5C5C
    i++
  imsg = ipad.concat(messageBytes)
  ihash = core_sha256(imsg, 512 + message.length * chrsz)
  omsg = opad.concat(ihash)
  ohash = core_sha256(omsg, 512 + 256)
  b64hash = binb2b64(ohash)
  urlhash = encodeURIComponent(b64hash)
  urlhash
  
Date::toISODate = new Function("with (this)\n    return " + "getFullYear()+'-'+addZero(getMonth()+1)+'-'" + "+addZero(getDate())+'T'+addZero(getHours())+':'" + "+addZero(getMinutes())+':'+addZero(getSeconds())+'.000Z'")

window.addZero = (n) ->
  ((if n < 0 or n > 9 then "" else "0")) + n
  
window.getNowTimeStamp = ->
  time = new Date()
  gmtTime = new Date(time.getTime() + (time.getTimezoneOffset() * 60000))
  gmtTime.toISODate()

window.get_agent = ->
  "thedealpandac-20"
  
window.getAccessKeyId = ->
  "AKIAJ563ZSAI2VQVMEHA"

window.getSecretAccessKey = ->
  "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"