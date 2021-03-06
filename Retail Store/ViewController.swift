//
//  ViewController.swift
//  Retail Store
//
//  Created by Atul Kshirsagar on 8/3/15.
//  Copyright © 2015 Atul Kshirsagar. All rights reserved.
//

import UIKit
import QuartzCore
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate {
    

    @IBOutlet weak var btnSwitchSearch: UIButton!
    
    @IBOutlet weak var lblDetails: UILabel!

    @IBOutlet weak var lblStatus: UILabel!
    
    var beaconRegion: CLBeaconRegion!
    
    var locationManager: CLLocationManager!
    
    var isSearchingForBeacons = false
    
    var lastFoundBeacon: CLBeacon! = CLBeacon()
    
    var lastProximity: CLProximity! = CLProximity.Unknown
    
    //application settings
    var appDefaults = Dictionary<String, AnyObject>()
    var uuidVal: String? = nil
    var serverUrl: String? = nil
    let uuid_pref = "uuid_preference"
    let serverurl_pref = "serverurl_preference"
    
    func getUserPreference(forKey: String) -> AnyObject {
        return NSUserDefaults.standardUserDefaults().objectForKey(forKey)!
    }
    
    func getAppSettings() {
        //get app settings
//        appDefaults["uuid_preference"] = "7C34D9A1-A7F1-4D79-AF82-7D8470094418"
//        appDefaults["serverurl_preference"] = "http://localhost:9090/car/"
        if let path = NSBundle.mainBundle().pathForResource("Defaults", ofType: "plist") {
            if let dict = NSDictionary(contentsOfFile: path) as? Dictionary<String, AnyObject> {
                appDefaults = dict
            }
        }
        
        NSUserDefaults.standardUserDefaults().registerDefaults(appDefaults)
        
        uuidVal = getUserPreference(uuid_pref) as? String
        serverUrl = getUserPreference(serverurl_pref) as? String
        
        NSUserDefaults.standardUserDefaults().synchronize()
        
    }
    
    func observeSettings(notification: NSNotification) {
          print("observeSettings() called, \(notification)");
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        lblDetails.hidden = true
        btnSwitchSearch.layer.cornerRadius = 10.0
        
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        
        getAppSettings()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: ("observeSettings"), name: NSUserDefaultsDidChangeNotification, object: nil)
        
        let uuid = NSUUID(UUIDString: uuidVal!)
        if (uuid != nil) {
            beaconRegion = CLBeaconRegion(proximityUUID: uuid!, identifier: "com.cisco.car")
            beaconRegion.notifyOnEntry = true
            beaconRegion.notifyOnExit = true
        }else{
//            let alert = UIAlertController(title: "Error", message: "Invalid beacon id", preferredStyle: UIAlertControllerStyle.Alert)
//            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
//            self.presentViewController(alert, animated: true, completion: nil)
            let alert = UIAlertView()
            alert.title = "Error"
            alert.message = "Invalid beacon id, " + uuidVal!
            alert.addButtonWithTitle("OK")
            alert.show()
            
            btnSwitchSearch.enabled = false //disable search button
        }

    }
    
    @IBAction func switchSearch(sender: AnyObject) {
        if !isSearchingForBeacons {
            locationManager.requestAlwaysAuthorization()
            locationManager.startMonitoringForRegion(beaconRegion)
            locationManager.startUpdatingLocation()
            
            btnSwitchSearch.setTitle("Stop Searching", forState: UIControlState.Normal)
            lblStatus.text = "Searching beacons..."
        }
        else {
            locationManager.stopMonitoringForRegion(beaconRegion)
            locationManager.stopRangingBeaconsInRegion(beaconRegion)
            locationManager.stopUpdatingLocation()
            
            btnSwitchSearch.setTitle("Start Searching", forState: UIControlState.Normal)
            lblStatus.text = "Not running"
            lblDetails.hidden = true
        }
        
        isSearchingForBeacons = !isSearchingForBeacons
    }
    
    //locationmanager
    func locationManager(manager: CLLocationManager, didStartMonitoringForRegion region: CLRegion) {
        locationManager.requestStateForRegion(region)
    }
    
    
    func locationManager(manager: CLLocationManager, didDetermineState state: CLRegionState, forRegion region: CLRegion) {
        if state == CLRegionState.Inside {
            locationManager.startRangingBeaconsInRegion(beaconRegion)
        }
        else {
            locationManager.stopRangingBeaconsInRegion(beaconRegion)
        }
    }
    
    
    func locationManager(manager: CLLocationManager, didEnterRegion region: CLRegion) {
        lblDetails.text = "Beacon in range"
        lblDetails.hidden = false
        //notify: enered region
        sendToserver(["event": "entered", "region": region.identifier])
    }
    
    
    func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
        lblStatus.text = "No beacons in range"
        lblDetails.hidden = true
        //notify: left region
        sendToserver(["event": "exited", "region": region.identifier])
    }
    
    
    func locationManager(manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], inRegion region: CLBeaconRegion) {
        var shouldHideBeaconDetails = true
        
        let foundBeacons = beacons
//        {
            if foundBeacons.count > 0 {
                if let closestBeacon = foundBeacons[0] as? CLBeacon {
                    if closestBeacon.proximityUUID.UUIDString != lastFoundBeacon.proximityUUID.UUIDString
                        || closestBeacon.major != lastFoundBeacon.major
                        || closestBeacon.minor != lastFoundBeacon.minor
                        || lastProximity != closestBeacon.proximity  {
                        
                        print("closestBeacon: \(closestBeacon) lastFoundBeacon \(lastFoundBeacon) lastProximity: \(lastProximity!)")
                            
                        lastFoundBeacon = closestBeacon
                        lastProximity = closestBeacon.proximity
                        
                        var proximityMessage: String!
                        switch lastFoundBeacon.proximity {
                        case CLProximity.Immediate:
                            proximityMessage = "Very close"
                            
                        case CLProximity.Near:
                            proximityMessage = "Near"
                            
                        case CLProximity.Far:
                            proximityMessage = "Far"
                            
                        default:
                            proximityMessage = "Where's the beacon?"
                        }
                        
                        shouldHideBeaconDetails = false
                        
                        lblDetails.text = "Beacon Details:\nMajor = " + String(closestBeacon.major.intValue) + "\nMinor = " + String(closestBeacon.minor.intValue) + "\nDistance: " + proximityMessage
                        
                        //notify: proximity
                        sendToserver(["event": "proximity"
                            , "region": region.identifier
                            , "beaconId": closestBeacon.proximityUUID.UUIDString
                            , "beaconMajor": closestBeacon.major.stringValue
                            , "beaconMinor" : closestBeacon.minor.stringValue
                            , "distance": proximityMessage])
                    }
                }
            }
//        }
        
        lblDetails.hidden = shouldHideBeaconDetails
    }
    
    
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        print(error)
    }
    
    
    func locationManager(manager: CLLocationManager, monitoringDidFailForRegion region: CLRegion?, withError error: NSError) {
        print(error)
    }
    
    
    func locationManager(manager: CLLocationManager, rangingBeaconsDidFailForRegion region: CLBeaconRegion, withError error: NSError) {
        print(error)
    }
    //locationmanager
    
    //server comm
    
    func eventPaylod(eventdata: Dictionary<String, String>) -> Dictionary<String, String> {
        var evt = Dictionary<String, String>();
        evt["mac"] = UIDevice.currentDevice().identifierForVendor!.UUIDString
        for (key, value) in eventdata {
            evt[key] = value
        }
        return evt
    }
    
    func sendToserver(params: Dictionary<String, String>) {
        let url = getUserPreference(serverurl_pref) as? String
        post(params, url: url!)
    }
    
    func post(params : Dictionary<String, String>, url : String) {
        var request = NSMutableURLRequest(URL: NSURL(string: url)!)
        var session = NSURLSession.sharedSession()
        request.HTTPMethod = "POST"
        
        request.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(params, options: NSJSONWritingOptions.PrettyPrinted)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = session.dataTaskWithRequest(request, completionHandler: {data, response, error -> Void in
            print("Response: \(response)")
            let strData = NSString(data: data!, encoding: NSUTF8StringEncoding)
            print("Body: \(strData)")
//            let err: NSError?
            let json = try! NSJSONSerialization.JSONObjectWithData(data!, options: .MutableLeaves) as? NSDictionary
            
            
            // Did the JSONObjectWithData constructor return an error? If so, log the error to the console
            if(error != nil) {
                print(error!.localizedDescription)
                let jsonStr = NSString(data: data!, encoding: NSUTF8StringEncoding)
                print("Error could not parse JSON: '\(jsonStr)'")
            }
            else {
                // The JSONObjectWithData constructor didn't return an error. But, we should still
                // check and make sure that json has a value using optional binding.
                if let parseJSON = json {
                    // Okay, the parsedJSON is here, let's get the value for 'success' out of it
                    let success = parseJSON["success"] as? Int
                    print("Succes: \(success)")
                }
                else {
                    // Woa, okay the json object was nil, something went worng. Maybe the server isn't running?
                    let jsonStr = NSString(data: data!, encoding: NSUTF8StringEncoding)
                    print("Error could not parse JSON: \(jsonStr)")
                }
            }
        })
        
        task!.resume()
    }
    //server comm

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

