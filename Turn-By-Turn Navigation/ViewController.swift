//
//  ViewController.swift
//  Turn-By-Turn Navigation
//
//  Created by Admin on 26/12/22.
//

import UIKit
import MapKit
import CoreLocation
import AVFoundation

class ViewController: UIViewController  {
    
    @IBOutlet weak var mapView: MKMapView!
    
    let searchController = UISearchController()
    
    let locationManager = CLLocationManager()
    var currentCoordinate: CLLocationCoordinate2D! = nil
    
    var steps = [MKRoute.Step]()
    var directionsArray: [MKDirections] = []
    let speechSynthesizer = AVSpeechSynthesizer()
    
    var stepCounter = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureSearchBar()
        locationManager.requestAlwaysAuthorization()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    
    }

    func configureSearchBar() {
        searchController.searchBar.delegate = self
        searchController.searchBar.placeholder = "Search here"
        searchController.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = searchController
    }
    
    func getDirections(to destination: MKMapItem) {
        //get the source and turn into cordinate
        let sourcePlacemark = MKPlacemark(coordinate: currentCoordinate)
        let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
        
        let directionRequest = MKDirections.Request()
        directionRequest.source = sourceMapItem
        directionRequest.destination = destination
        directionRequest.transportType = .automobile
        
        let direction = MKDirections(request: directionRequest)
        //removing the previous overlay if any
        self.resetMapView(withNew: direction)
        
        direction.calculate { response, _ in
            guard let response = response else { return}
            guard let primaryRoute = response.routes.first else {
                return
            }
            self.mapView.addOverlay(primaryRoute.polyline)
            
            //for deleting previous
            self.locationManager.monitoredRegions.forEach { self.locationManager.stopMonitoring(for: $0)}
            //saving the steps
            self.steps = primaryRoute.steps
            
            for i in 0 ..< primaryRoute.steps.count {
                let step = primaryRoute.steps[i]
                print(step.instructions)
                print(step.distance)
                let region = CLCircularRegion(center: step.polyline.coordinate, radius: 20, identifier: "\(i)")
                self.locationManager.startMonitoring(for: region)
                
                //adding geofencing at turn to get notification
                let circle = MKCircle(center: region.center, radius: region.radius)
                self.mapView.addOverlay(circle)
            }
            
            let initialMessage = "In \(self.steps[0].distance) meter,\(self.steps[0].instructions) then in \(self.steps[1].distance) meters, \(self.steps[1].instructions)."
            
            let speechUtterance = AVSpeechUtterance(string: initialMessage)
           // speechUtterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            self.speechSynthesizer.speak(speechUtterance)
            self.stepCounter += 1
            
        }
    }
    
    func resetMapView(withNew directions: MKDirections) {
            mapView.removeOverlays(mapView.overlays)
            directionsArray.append(directions)
            let _ = directionsArray.map { $0.cancel() }
        }
   
    
}

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        manager.stopUpdatingLocation()
        guard let currentLocation = locations.first else {return}
        currentCoordinate = currentLocation.coordinate
        mapView.userTrackingMode = .followWithHeading
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("entered")
    }
}

extension ViewController: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
        let localSearchRequest = MKLocalSearch.Request()
        localSearchRequest.naturalLanguageQuery = searchBar.text
        
        let region = MKCoordinateRegion(center: currentCoordinate, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        localSearchRequest.region = region
        
        let localSearch = MKLocalSearch(request: localSearchRequest)
        localSearch.start { response, error in
            guard let response = response else { return}
            print("\(response.mapItems) response")
            guard let firstMapItem =  response.mapItems.first else { return}
            
            self.getDirections(to: firstMapItem)
        }
        
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        let sourcePlacemark = MKPlacemark(coordinate: currentCoordinate)
        let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
        
        let directionRequest = MKDirections.Request()
        directionRequest.source = sourceMapItem
        let direction = MKDirections(request: directionRequest)
        //removing the previous overlay if any
        self.resetMapView(withNew: direction)
        
    }
}

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKPolyline {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = .blue
            renderer.lineWidth = 10
            return renderer
        }
        
        if overlay is MKCircle {
            let renderer = MKCircleRenderer(overlay: overlay)
            renderer.strokeColor = .red
            renderer.fillColor = .red
            renderer.alpha = 0.5
            return renderer
        }
        //default
        return MKOverlayRenderer()
    }
}
