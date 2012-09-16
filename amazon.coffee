window.test_string = """GET
webservices.amazon.com
/onca/xml
AWSAccessKeyId=AKIAIOSFODNN7EXAMPLE&ItemId=0679722769&Operation=ItemLookup&ResponseGroup=ItemAttributes%2COffers%2CImages%2CReviews&Service=AWSECommerceService&Timestamp=2009-01-01T12%3A00%3A00Z&Version=2009-01-06"""

window.test_string2 = """GET
webservices.amazon.com
/onca/xml
AWSAccessKeyId=AKIAIOSFODNN7EXAMPLE&AssociateTag=mytag-20&Item.1.OfferListingId=j8ejq9wxDfSYWf2OCp6XQGDsVrWhl08GSQ9m5j%2Be8MS449BN1XGUC3DfU5Zw4nt%2FFBt87cspLow1QXzfvZpvzg%3D%3D&Item.1.Quantity=3&Operation=CartCreate&Service=AWSECommerceService&Timestamp=2009-01-01T12%3A00%3A00Z&Version=2009-01-01"""


window.create_test_string = ()->
  timestamp = moment.utc().format("YYYY-MM-DDTHH:mm:ss")
  AWSAccessKeyId = "AKIAJ563ZSAI2VQVMEHA"
  AssociateTag = "thedealpandac-20"
  a = """AWSAccessKeyId=#{ AWSAccessKeyId }&AssociateTag=#{ AssociateTag }&Item.1.OfferListingId=j8ejq9wxDfSYWf2OCp6XQGDsVrWhl08GSQ9m5j%2Be8MS449BN1XGUC3DfU5Zw4nt%2FFBt87cspLow1QXzfvZpvzg%3D%3D&Item.1.Quantity=3&Operation=CartCreate&Service=AWSECommerceService&Timestamp=#{ timestamp }&Version=2009-01-01"""
  

#given a product, give a url for that product
window.create_url = ( product ) ->
  AWSAccessKeyId = "AKIAJ563ZSAI2VQVMEHA"
  AssociateTag = "thedealpandac-20"  
  dk = "RWzMxmIR3w6zjqzr7Qe1TF5Wb8t1VCqBjglWpUsn"
  
  timestamp = moment.utc().format("YYYY-MM-DDTHH:mm:ss")
  
  a = "http://webservices.amazon.com/onca/xml?Service=AWSECommerceService&Operation=ItemSearch&" +
      "AWSAccessKeyId=#{ AWSAccessKeyId }&AssociateTag=#{ AssociateTag }&SearchIndex=Apparel&" +
      "Keywords=#{ product }&Timestamp=#{ timestamp }"
  
  encoded_a = encodeURI(a)

  all = 
    "AssociateTag": AssociateTag
    #"AWSAccessKeyId": AWSAccessKeyId
    "Keywords": product
    "Operation": "ItemSearch"
    "SearchIndex": "Blended"
    "Service": "AWSECommerceService"
    "Timestamp": timestamp

  console.log(all)

  x = ""
  for key, value of all 
    console.log(key)
    x = x + key+ "=" + encodeURI(value) + "&"
  
  final_string = """GET
webservices.amazon.com
/onca/xml""" +"\n"+ x
    
  console.log(final_string)

  signature = fnSignQuery( final_string, dk )
  
  console.log("signature", signature)
  
  a = a+"&Signature=#{ signature }"

window.sign_and_send= (query) ->
  final_string = """GET
webservices.amazon.com
/onca/xml""" +"\n"+ query 
  
  signature = fnSignQuery( final_string, "RWzMxmIR3w6zjqzr7Qe1TF5Wb8t1VCqBjglWpUsn" )
  console.log(final_string )
  x = "http://webservices.amazon.com/onca/xml?" + query + "&Signature=#{ signature }"
  console.log(x)
