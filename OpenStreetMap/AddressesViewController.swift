//
//  AddressesViewController.swift
//  OpenStreetMap
//
//  Created by Richard Fairhurst on 02/06/2015.
//  Copyright (c) 2015 Richard Fairhurst. All rights reserved.
//

import UIKit
import CoreLocation
import AVFoundation

struct Address {
	var location:CLLocation!
	var street:String!
	var number:String!
}

class AddressesViewController: UIViewController, OEEventsObserverDelegate, CLLocationManagerDelegate, AVSpeechSynthesizerDelegate {

	var lmPath:String!
	var dicPath:String!
	var words:[String:Int] = [
		"LEFT": -1,
		"RIGHT": -2,
		"AND": -3,
		"DELETE": -4,
		"LAST": -5,
		"SAVE": -6,
		"ADDRESSES": -7,
		"ONE": 1, "TWO": 2, "THREE": 3, "FOUR": 4, "FIVE": 5,
		"SIX": 6, "SEVEN": 7, "EIGHT": 8, "NINE": 9, "TEN": 10,
		"ELEVEN": 11, "TWELVE": 12, "THIRTEEN": 13, "FOURTEEN": 14, "FIFTEEN": 15,
		"SIXTEEN": 16, "SEVENTEEN": 17, "EIGHTEEN": 18, "NINETEEN": 19,
		"TWENTY": 20, "THIRTY": 30, "FORTY": 40, "FIFTY": 50, "SIXTY": 60, "SEVENTY": 70,
		"EIGHTY": 80, "NINETY": 90, "HUNDRED": 100 ]
	var openEarsEventsObserver: OEEventsObserver!

	let synth = AVSpeechSynthesizer()

	var addresses:Array<Address> = []
	
	@IBOutlet weak var roadLabel: UILabel!
	@IBOutlet weak var saveButton: UIButton!
	@IBOutlet weak var speechLabel: UILabel!

	let locationManager = CLLocationManager()
	var currentStreet:String?
	var currentLocation:CLLocation?
	var overpassCalled = false
	
	var serverConnection:OSMConnection!
	
	override func viewDidLoad() {
        super.viewDidLoad()

		// Configure location
		locationManager.delegate = self
		locationManager.desiredAccuracy = kCLLocationAccuracyBest
		if (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.NotDetermined){
			locationManager.requestWhenInUseAuthorization()
		} else {
			locationManager.startUpdatingLocation()
		}

		// Configure speech synthesiser
		synth.delegate = self

		// Set up OSM connection
		serverConnection = OSMConnection()
		
		// Configure OpenEars
		loadOpenEars()
		startListening()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

	// UI
	
	@IBAction func saveTapped(sender: AnyObject) {
		saveAllAddresses()
	}
	
	@IBAction func refreshRoad(sender: AnyObject) {
		getStreetsFromOverpass()
	}

	
	// Location methods
	
	func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
		println("Authorization status changed to \(status.rawValue)")
		switch status {
			case .AuthorizedAlways, .AuthorizedWhenInUse: locationManager.startUpdatingLocation()
			default: locationManager.stopUpdatingLocation()
		}
	}

	func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
		println("didFailWithError")
		let errorType = error.code == CLError.Denied.rawValue ? "Access Denied": "Error \(error.code)"
		let alertController = UIAlertController(title: "Location Manager Error", message: errorType, preferredStyle: .Alert)
		let okAction = UIAlertAction(title: "OK", style: .Cancel, handler: { action in })
		alertController.addAction(okAction)
		presentViewController(alertController, animated: true, completion: nil)
	}
	
	func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
//		println("didUpdateLocations")
		currentLocation = (locations as! [CLLocation])[locations.count - 1]
		if let loc = currentLocation {
			if loc.horizontalAccuracy<0 || loc.horizontalAccuracy>100 || loc.verticalAccuracy>100 {
				// don't use inaccurate positions
				currentLocation = nil
			} else if !overpassCalled {
				getStreetsFromOverpass()
			}
		}
	}
	
	// Overpass API communication
	
	func getStreetsFromOverpass() {
		if let loc = currentLocation {
			overpassCalled = true
			let latStr = String(format: "%f", loc.coordinate.latitude)
			let lonStr = String(format: "%f", loc.coordinate.longitude)
			println("Requesting from Overpass at \(latStr), \(lonStr)")
			let overpassURL = "http://overpass-api.de/api/interpreter?data=way(around:50,\(latStr),\(lonStr))[\"highway\"][\"name\"];out;".stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)
			let url = NSURL(string: overpassURL!)!
			let task = NSURLSession.sharedSession().dataTaskWithURL(url) {(data, response, error) in
				let xml = NSString(data: data, encoding: NSUTF8StringEncoding) as! String
				self.parseOverpassResponse(xml)
			}
			task.resume()
		}
	}
	
	func parseOverpassResponse(xmlStr:String) {
		let xml = SWXMLHash.parse(xmlStr)
		if let name = getFirstWayName(xml) {
			println(name)
			dispatch_async(dispatch_get_main_queue()) {
				self.currentStreet = name
				self.roadLabel.text = name
			}
		}
	}
	
	func getFirstWayName(xml:XMLIndexer) -> String? {
		for way in xml["osm"]["way"] {
			for tag in way["tag"] {
				if tag.element?.attributes["k"]=="name" {
					return tag.element?.attributes["v"]
				}
			}
		}
		return nil
	}

	// Address management
	
	func deleteLastAddress() {
		if addresses.count == 0 {
			say("Nothing to delete")
			return
		}
		addresses.removeLast()
		say("Deleted")
	}
	
	func saveAllAddresses() {
		if addresses.count == 0 {
			say("Nothing to save")
			return
		}
		println("Saving addresses")
		serverConnection.openChangeset( { ()->Void in
			println("Closure after changeset opened")
			self.serverConnection.saveAddresses(self.addresses, onComplete: { ()->Void in 
				self.addresses=[]
				self.say("Addresses saved")
			})
		})
	}
	
	// AVSpeechSynthesizer delegate

	func say(str:String!) {
		stopListening()
		var myUtterance = AVSpeechUtterance(string: str)
		myUtterance.rate = 0.1
		synth.speakUtterance(myUtterance)
	}
	
	func speechSynthesizer(synthesizer:AVSpeechSynthesizer!, didFinishSpeechUtterance utterance:AVSpeechUtterance!) {
		println("finished speaking")
		startListening()
	}
	
	//OpenEars methods from http://www.politepix.com/forums/topic/openears-with-swift/
	
	func loadOpenEars() {
		self.openEarsEventsObserver = OEEventsObserver()
		self.openEarsEventsObserver.delegate = self
		
		var lmGenerator: OELanguageModelGenerator = OELanguageModelGenerator()
		
		var name = "LanguageModelFileStarSaver"
		let list = words.keys.array
		lmGenerator.generateLanguageModelFromArray(list, withFilesNamed: name, forAcousticModelAtPath: OEAcousticModel.pathToModel("AcousticModelEnglish"))
		
		lmPath = lmGenerator.pathToSuccessfullyGeneratedLanguageModelWithRequestedName(name)
		dicPath = lmGenerator.pathToSuccessfullyGeneratedDictionaryWithRequestedName(name)
		println("OpenEars loaded")
	}
	
	func pocketsphinxDidReceiveHypothesis(hypothesis: String, recognitionScore: String, utteranceID: String) {
		speechLabel.text = "\(hypothesis) (\(recognitionScore), \(utteranceID))"
		
		// Is it a special response?
		if hypothesis.rangeOfString("DELETE LAST") != nil {
			deleteLastAddress()
			saveButton.setTitle("Save \(addresses.count) addresses", forState: .Normal)
			return
		} else if hypothesis.rangeOfString("SAVE ADDRESSES") != nil {
			saveAllAddresses()
			return
		}
		
		// Parse the number response
		let rec = hypothesis.componentsSeparatedByString(" ")
		var offset = 0
		if rec.count < 2 {
			say("K?")	// you'll have to excuse him, he's from Barcelona
			return
		} else if rec[0]=="LEFT" {
			offset = -10
		} else if rec[0]=="RIGHT" {
			offset = 10
		} else {
			say("Didn't understand \(hypothesis)")
			return
		}
		var num:Int! = 0
		for i in 1..<rec.count {
			if let n = words[rec[i]] {
				if n > 0 { num = num + n }
			}
			// *** This doesn't deal with "one hundred and"
		}
		if num == 0 { return }

		if currentLocation == nil { // *** or not accurate enough...
			say("Sorry, no GPS fix yet")
			return
		}
		// Project point on left/right of road
		var lat = currentLocation!.coordinate.latitude
		var lon = currentLocation!.coordinate.longitude
		if currentLocation!.course > -1 {
			let d2r = 3.14159265359 / 180.0
			let course = 45.0 //currentLocation!.course as Double
			let rad = course * d2r
			let dist = Double(offset) / 6371000.0
			let lat1 = lat * d2r
			let lon1 = lon * d2r
			let lat2 = asin(sin(lat1) * cos(dist) + cos(lat1) * sin(dist) * cos(rad))
			let lon2 = lon1 + atan2(sin(rad) * sin(dist) * cos(lat1),
								   cos(dist) - sin(lat1) * sin(lat2))
			lat=lat2 / d2r
			lon=lon2 / d2r
		}
		
		// Create new address
		let address = Address(location: CLLocation(latitude: lat, longitude: lon), 
							  street: currentStreet, number: String(num) )
		addresses.append(address)
		saveButton.setTitle("Save \(addresses.count) addresses", forState: .Normal)
		say("\(rec[0]) \(num)")
		println("Received \(hypothesis), number \(num), offset \(offset), score \(recognitionScore), ID \(utteranceID)")
	}
	
	func pocketsphinxDidStartListening() {
		println("Pocketsphinx is now listening.")
	}
	
	func pocketsphinxDidDetectSpeech() {
//		println("Pocketsphinx has detected speech.")
	}
	
	func pocketsphinxDidDetectFinishedSpeech() {
//		println("Pocketsphinx has detected a period of silence, concluding an utterance.")
	}
	
	func pocketsphinxDidStopListening() {
		println("Pocketsphinx has stopped listening.")
	}
	
	func pocketsphinxDidSuspendRecognition() {
		println("Pocketsphinx has suspended recognition.")
	}
	
	func pocketsphinxDidResumeRecognition() {
		println("Pocketsphinx has resumed recognition.")
	}
	
	func pocketsphinxDidChangeLanguageModelToFile(newLanguageModelPathAsString: String, newDictionaryPathAsString: String) {
		println("Pocketsphinx is now using the following language model: \(newLanguageModelPathAsString) and the following dictionary: \(newDictionaryPathAsString)")
	}
	
	func pocketSphinxContinuousSetupDidFailWithReason(reasonForFailure: String) {
		println("Listening setup wasn't successful and returned the failure reason: \(reasonForFailure)")
	}
	
	func pocketSphinxContinuousTeardownDidFailWithReason(reasonForFailure: String) {
		println("Listening teardown wasn't successful and returned the failure reason: \(reasonForFailure)")
	}
	
	func testRecognitionCompleted() {
		println("A test file that was submitted for recognition is now complete.")
	}
	
	func startListening() {
		OEPocketsphinxController.sharedInstance().setActive(true, error: nil)
		OEPocketsphinxController.sharedInstance().startListeningWithLanguageModelAtPath(lmPath, dictionaryAtPath: dicPath, acousticModelAtPath: OEAcousticModel.pathToModel("AcousticModelEnglish"), languageModelIsJSGF: false)
		//OEPocketsphinxController.sharedInstance().secondsOfSilenceToDetect = 0.4
		OEPocketsphinxController.sharedInstance().vadThreshold = 3.5
	}
	
	func stopListening() {
		OEPocketsphinxController.sharedInstance().stopListening()
	}
	
	//OpenEars methods end

}
