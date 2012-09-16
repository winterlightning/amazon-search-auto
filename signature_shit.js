function encode_base64(data) {
	var out = "", c1, c2, c3, e1, e2, e3, e4;
	for(var i = 0; i < data.length; ) {
		c1 = data.charCodeAt(i++);
		c2 = data.charCodeAt(i++);
		c3 = data.charCodeAt(i++);
		e1 = c1 >> 2;
		e2 = ((c1 & 3) << 4) + (c2 >> 4);
		e3 = ((c2 & 15) << 2) + (c3 >> 6);
		e4 = c3 & 63;
		if(isNaN(c2))
			e3 = e4 = 64;
		else if(isNaN(c3))
			e4 = 64;
		out += tab.charAt(e1) + tab.charAt(e2) + tab.charAt(e3) + tab.charAt(e4);
	}
	return out;
}

function decode_base64(data) {
	var out = "", c1, c2, c3, e1, e2, e3, e4;
	for(var i = 0; i < data.length; ) {
		e1 = tab.indexOf(data.charAt(i++));
		e2 = tab.indexOf(data.charAt(i++));
		e3 = tab.indexOf(data.charAt(i++));
		e4 = tab.indexOf(data.charAt(i++));
		c1 = (e1 << 2) + (e2 >> 4);
		c2 = ((e2 & 15) << 4) + (e3 >> 2);
		c3 = ((e3 & 3) << 6) + e4;
		out += String.fromCharCode(c1);
		if(e3 != 64)
			out += String.fromCharCode(c2);
		if(e4 != 64)
			out += String.fromCharCode(c3);
	}
	return out;
}

var tab = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

/* ------ privates ------ */

function array_to_string(ary) {
	var str = "";
	for(var i = 0; i < ary.length; i++) {
		str += String.fromCharCode(ary[i]);
	}
	return str;
}

// uses http://point-at-infinity.org/jssha256/
function local_HMAC_SHA256_MAC(strKey, strMsg) {
	HMAC_SHA256_init(strKey);
	HMAC_SHA256_write(strMsg);
	var aHash = HMAC_SHA256_finalize();
	return array_to_string(aHash);
}

function fnTranslate(str, aTranslate) {
	for(var i = 0; i < aTranslate.length; i++) {
		str = str.replace(aTranslate[i][0], aTranslate[i][1]);
	}
	return str;
}

function encodeURIComponentAWS(str) {
	return fnTranslate(encodeURIComponent(str), [[/!/g, "%21"], [/'/g, "%27"], [/\(/g, "%28"], [/\)/g, "%29"], [/\*/g, "%2A"]]);
}

function toZString(dt) {
	// "Sun, 10 May 2009 18:45:50 UTC" to "2009-05-10T18:45:50Z":
	//  note: ff toUTCString returns "Sun, 17 May 2009 23:31:11 GMT" - !
	return dt.toUTCString().replace(/.{3}, (\d{1,2}) .{3} (\d{4}) (\d{2}:\d{2}:\d{2}) .{3}/, function(strMatch, strDay, strYear, strTime) {
		var strDate = (dt.getUTCDate()).toString().replace(/^(\d)$/, "0$1");
		var strMonth = (dt.getUTCMonth() + 1).toString().replace(/^(\d)$/, "0$1");
		return strYear + "-" + strMonth + "-" + strDate + "T" + strTime + "Z";
	});
}

function timestamp() {
	return toZString(new Date());
}

// given methond ( "POST" or "GET" ), AWS query (in GET form) and "secret access key",
// return object with Timestamp and Signature
function fnSignature(strMethod, strQuery, strKey) {
	var bEncode = strMethod == "GET";

	//var strTimestamp = timestamp();
	//strQuery += "&Timestamp=" + ( bEncode ? strTimestamp : encodeURIComponentAWS( strTimestamp ) );

	var strToSign = strQuery.replace(/(https?:\/\/)([^\/]*)(\/.*)\?(.*)/i, function(strMatch, strScheme, strHost, strUri, strParams) {
		var aParams = strParams.split("&").sort();
		if(bEncode) {
			for(var i = 0; i < aParams.length; i++) {
				var aKV = aParams[i].split("=");
				for(var j = 0; j < aKV.length; j++) {
					aKV[j] = encodeURIComponentAWS(aKV[j]);
				}
				aParams[i] = aKV.join("=");
			}
		}
		strParams = aParams.join("&");
		strHost = strHost.toLowerCase();
		return ([strMethod, strHost, strUri, strParams]).join("\n");
	});
	// Base64 from http://ecmanaut.blogspot.com/2007/11/javascript-base64-singleton.html
	var strSignature = encode_base64(local_HMAC_SHA256_MAC(strKey, strToSign));
	if(bEncode) {
		strSignature = encodeURIComponentAWS(strSignature);
	}

	return strSignature;
}

/* ------ form helpers ------ */

function encodeKV(strKey, strVal) {
	var strK = encodeURIComponentAWS(strKey);
	var strV = encodeURIComponentAWS(strVal);
	return strK + "=" + strV;
}

function getKV(elem) {
	return encodeKV(elem.name, elem.value);
}

// getQuery collects up all field values to be POSTed from form,
// constructs _uri_encoded_ GET style query with form's action
// _all_ fields must be collected, even if empty (except those not sent).
function getQuery(oForm) {
	var aQuery = [];

	var colElements = oForm.elements;
	for(var i = 0; i < colElements.length; i++) {
		var elem = colElements[i];
		var strType = elem.type ? elem.type.toLowerCase() : "";
		var strTag = elem.tagName.toLowerCase();

		switch( true ) {

			case strType == "hidden":
			case strType == "text":
			case strType == "checkbox" && elem.checked:
			case strType == "radio" && elem.checked:
			case strTag == "textarea":

				aQuery.push(getKV(elem));
				break;

			case strTag == "select":
				var bDone = false;
				for(var j = 0; j < elem.options.length; j++) {
					if(!bDone && elem.options[j].selected) {
						aQuery.push(encodeKV(elem.name, elem.options[j].value));
						bDone = true;
					}
				}
				if(!bDone) {// or are empty selects not POSTed ?
					aQuery.push(encodeKV(elem.name, ""));
				}
				break;

			default:
			// nothin'
		}
	}
	return oForm.action + "?" + aQuery.join("&");
}

function setHidden(oForm, strName, strValue) {
	var elem = oForm.elements[strName];
	if(!elem) {
		elem = document.createElement("input");
		elem.type = "hidden";
		elem.name = strName;
		oForm.appendChild(elem);
	}
	elem.value = strValue;
}

/* ------ publics ------ */

//  get timestamp & signature for form
function fnFormSignature(oForm, strKey) {
	return fnSignature(oForm.method.toUpperCase(), getQuery(oForm), strKey);
}

//  get timestamp & signature for query
function fnQuerySignature(strQuery, strKey) {
	return fnSignature("GET", strQuery, strKey);
}

// sign form with key: add signature & timestamp
function fnSignForm(oForm, strKey) {
	var oSign = fnFormSignature(oForm, strKey);
	setHidden(oForm, "Timestamp", oSign.Timestamp);
	setHidden(oForm, "Signature", oSign.Signature);
}

// sign query with key: add signature & timestamp
function fnSignQuery(strQuery, strKey) {
	var oSign = fnQuerySignature(strQuery, strKey);
	return oSign
}