//
//  OSMConnection.swift
//  OpenStreetMap
//
//  Created by Richard Fairhurst on 04/06/2015.
//  Copyright (c) 2015 Richard Fairhurst. All rights reserved.
//

/*	Really ridiculously basic OSM connection class.

	Obvious things that are wrong:
	- doesn't create XML properly, just interpolates into a string.
	  Hope you didn't have any double-quotes in your street name or anything.
	  (AEXML looks like a good solution - https://github.com/tadija/AEXML )
	- doesn't squawk on errors
	- doesn't parse upload response
	- um, basic auth. TomH will kill me
*/

import Foundation

class OSMConnection {

	let OSM_BASE_URL = "http://www.openstreetmap.org/api/0.6/"
//	let OSM_BASE_URL = "http://api06.dev.openstreetmap.org/api/0.6/"
	
	let defaults = NSUserDefaults.standardUserDefaults()
	var password:String? {
		get { return defaults.stringForKey("password_preference") }
	}
	var username:String? {
		get { return defaults.stringForKey("username_preference") }
	}

	let queue:NSOperationQueue = NSOperationQueue()

	var changeset_id:Int?
	var node_id:Int!
	var data:NSMutableData = NSMutableData()
	
	// Top-level methods for talking to the API
	
	func openChangeset(onComplete: (() -> Void)?) {
		// open a changeset
		println("In openChangeset")
		if changeset_id != nil { 
			if onComplete != nil { onComplete!(); }
			return
		}
		if username==nil || password==nil { return; } // should throw an alert

		var xmlstr="<osm><changeset><tag k=\"created_by\" v=\"OpenStreetMap.app prototype\" /></changeset></osm>"
		var req = OSMRequest("PUT", path: "changeset/create", body: xmlstr)

		println("Sending request")
		NSURLConnection.sendAsynchronousRequest(req, queue: queue, completionHandler:{ (response: NSURLResponse!, data: NSData!, error: NSError!) -> Void in
			println("Got response")
			let body = NSString(data: data, encoding: NSUTF8StringEncoding) as! String
			println(body)
			if let id = body.toInt() {
				println(id)
				self.changeset_id = id
				self.node_id = -1
				println("Successfully created changeset \(id)")
				if onComplete != nil { onComplete!(); }
			}
		})
	}

	func closeChangeset() {
		// close the current changeset
		if changeset_id == nil { return; }

		var req = OSMRequest("PUT", path: "changeset/\(changeset_id!)/close", body: nil)
		NSURLConnection.sendAsynchronousRequest(req, queue: queue, completionHandler:{ (response: NSURLResponse!, data: NSData!, error: NSError!) -> Void in
			self.changeset_id = nil
			println("Closed changeset")
		})
	}

	func saveAddresses(addresses:[Address], onComplete: (() -> Void)?) {
		// upload a set of addresses to the current changeset
		if changeset_id==nil { return; }

		var xmlstr = "<osmChange version=\"0.3\" generator=\"OpenStreetMap.app\">\n"
		xmlstr += "  <create>\n"
		for address in addresses {
			let lat = address.location.coordinate.latitude
			let lon = address.location.coordinate.longitude
			xmlstr += "    <node changeset=\"\(changeset_id!)\" id=\"\(node_id)\" lat=\"\(lat)\" lon=\"\(lon)\">\n"
			xmlstr += "      <tag k=\"addr:housenumber\" v=\"\(address.number)\" />\n"
			xmlstr += "      <tag k=\"addr:street\" v=\"\(address.street)\" />\n"
			xmlstr += "    </node>\n"
			node_id = node_id-1
		}
		xmlstr += "  </create>\n"
		xmlstr += "</osmChange>\n"
		println(xmlstr)
		
		var req = OSMRequest("POST", path: "changeset/\(changeset_id!)/upload", body: xmlstr)
		NSURLConnection.sendAsynchronousRequest(req, queue: queue, completionHandler:{ (response: NSURLResponse!, data: NSData!, error: NSError!) -> Void in
			println("Uploaded changeset")
			let body = NSString(data: data, encoding: NSUTF8StringEncoding) as! String
			println(body)
			if onComplete != nil { onComplete!() }
		})
	}
	
	// Utility method for creating a request
	
	func OSMRequest(method:String, path:String, body:String?) -> NSMutableURLRequest {
		let loginString:NSString! = NSString(format: "%@:%@", username!, password!)
		let loginData:NSData! = loginString.dataUsingEncoding(NSUTF8StringEncoding)
		let base64LoginString = loginData.base64EncodedStringWithOptions(nil)
		
		// create the request
		let url:NSURL! = NSURL(string: OSM_BASE_URL+path)
		let request = NSMutableURLRequest(URL: url)
		request.HTTPMethod = method
		request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
		if let b = body {
			let bodyData = (b as NSString).dataUsingEncoding(NSUTF8StringEncoding)
			request.HTTPBody = bodyData
		}
		return request
	}
}
